#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$DIR/..
PRJROOT=$DIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/centrifuge_bucketing_all.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/centrifuge_bucketing.technical.config
USER_CONFIG=$PRJROOT/config/centrifuge_bucketing.config
STEP_CONFIG=$PRJROOT/config/analysis-input1_001.centrifuge.config

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

if [ -n "${CONDA_EXE:-}" ] && [ -x "$CONDA_EXE" ]; then
  export PATH="$(dirname "$CONDA_EXE"):$PATH"
elif ! command -v conda >/dev/null 2>&1; then
  echo "Error: conda was not found in PATH. Set PATH or CONDA_EXE to your conda binary." > /dev/stderr
  exit 1
fi

args=()
resume_set=false

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-align)
      args+=(--skip_align)
      shift
      ;;
    --skip-align=*)
      args+=("${1/--skip-align=/--skip_align=}")
      shift
      ;;
    --skip_align)
      args+=(--skip_align)
      shift
      ;;
    --skip_align=*)
      args+=("$1")
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
for arg in "${args[@]}"; do
  if [ "$arg" = "-resume" ] || [ "$arg" = "--resume" ]; then
    resume_set=true
    break
  fi
done

if ! $resume_set; then
  args+=(-resume)
fi

nextflow run "$PIPELINE_NF" \
  -c "$TECH_CONFIG_COMMON" \
  -c "$TECH_CONFIG_PIPE" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  "${args[@]}"
