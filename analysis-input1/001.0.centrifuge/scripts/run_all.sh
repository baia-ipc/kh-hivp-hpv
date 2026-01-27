#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$DIR/..
PRJROOT=$DIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/centrifuge_bucketing_all.nf
PIPELINE_CONFIG=$PRJROOT/config/centrifuge_bucketing.config
OUTDIR=$STEPDIR/output

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

if [ -z "${CONDA_OVERRIDE_CUDA:-}" ]; then
  export CONDA_OVERRIDE_CUDA=0
fi

args=()
skip_align=false
outdir_set=false
precomputed_set=false
resume_set=false

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-align)
      skip_align=true
      args+=(--skip_align)
      shift
      ;;
    --skip-align=*)
      skip_align=true
      args+=("${1/--skip-align=/--skip_align=}")
      shift
      ;;
    --skip_align)
      skip_align=true
      args+=(--skip_align)
      shift
      ;;
    --skip_align=*)
      skip_align=true
      args+=("$1")
      shift
      ;;
    --outdir)
      outdir_set=true
      args+=("$1")
      shift
      if [ $# -gt 0 ]; then
        args+=("$1")
        shift
      fi
      ;;
    --outdir=*)
      outdir_set=true
      args+=("$1")
      shift
      ;;
    --precomputed_root)
      precomputed_set=true
      args+=("$1")
      shift
      if [ $# -gt 0 ]; then
        args+=("$1")
        shift
      fi
      ;;
    --precomputed_root=*)
      precomputed_set=true
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

if ! $outdir_set; then
  args+=(--outdir "$OUTDIR")
fi

if $skip_align && ! $precomputed_set; then
  args+=(--precomputed_root "$OUTDIR")
fi

if ! $resume_set; then
  args+=(-resume)
fi

nextflow run "$PIPELINE_NF" \
  -c "$PIPELINE_CONFIG" \
  "${args[@]}"
