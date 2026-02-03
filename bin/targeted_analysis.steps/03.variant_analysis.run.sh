#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
VARIANT_PIPELINE_NF=$PRJROOT/pipelines/variant_analysis.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
VARIANT_PIPELINE_CONFIG=$PRJROOT/config/pipelines/variant_analysis.config
USER_CONFIG=$PRJROOT/config/user.config
DEFAULT_MULTIQC_CONFIG=$PRJROOT/pipelines/multiqc/variant_analysis.multiqc.yml

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/config/analyses/targeted_analysis.config
VARIANT_PROFILE=targeted_variant_analysis

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

args=()
resume_set=false
skip_database=false
for arg in "$@"; do
  case "$arg" in
    --skip-database|--skip_database)
      skip_database=true
      ;;
    *)
      args+=("$arg")
      if [ "$arg" = "-resume" ] || [ "$arg" = "--resume" ]; then
        resume_set=true
      fi
      ;;
  esac
done
if ! $resume_set; then
  args+=(-resume)
fi

if $skip_database; then
  args+=(--include_database false --multiqc_config "$DEFAULT_MULTIQC_CONFIG")
fi

nextflow run "$VARIANT_PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$VARIANT_PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$VARIANT_PROFILE" \
  "${args[@]}"
