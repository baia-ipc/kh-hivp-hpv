#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$DIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/centrifuge_bucketing_all.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/centrifuge_bucketing.config
USER_CONFIG=$PRJROOT/config/user.config

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/bin/config/prelim_analysis.config
PROFILE=preliminary_centrifuge

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
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$PROFILE" \
  "${args[@]}"
