#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/database_snps.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/database_snps.config
USER_CONFIG=$PRJROOT/config/user.config
STEP_CONFIG=$PRJROOT/bin/config/targeted_analysis.config
PROFILE=targeted_snps_samples_vs_db

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

args=()
resume_set=false
for arg in "$@"; do
  if [ "$arg" = "-resume" ] || [ "$arg" = "--resume" ]; then
    resume_set=true
  fi
  args+=("$arg")
done
if ! $resume_set; then
  args+=(-resume)
fi

nextflow run "$PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -profile "$PROFILE" \
  "${args[@]}"
