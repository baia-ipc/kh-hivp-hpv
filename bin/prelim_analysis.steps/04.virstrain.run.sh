#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/virstrain.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/virstrain.config
USER_CONFIG=$PRJROOT/config/user.config

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/config/analyses/prelim_analysis.config
PROFILE=preliminary_virstrain

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

args=()
resume_set=false
run_virstrain=false
for arg in "$@"; do
  case "$arg" in
    --run-virstrain|--run_virstrain)
      run_virstrain=true
      ;;
    --run-virstrain=*|--run_virstrain=*)
      value="${arg#*=}"
      if [ "$value" = "true" ] || [ "$value" = "1" ]; then
        run_virstrain=true
      fi
      ;;
  esac
  if [ "$arg" = "-resume" ] || [ "$arg" = "--resume" ]; then
    resume_set=true
  fi
  args+=("$arg")
done
if ! $run_virstrain; then
  echo "VirStrain disabled (pass --run-virstrain to run)."
  exit 0
fi
if ! $resume_set; then
  args+=(-resume)
fi

nextflow run "$PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$PROFILE" \
  "${args[@]}"
