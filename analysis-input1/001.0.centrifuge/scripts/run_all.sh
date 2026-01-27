#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT=$DIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/centrifuge_bucketing_all.nf
PIPELINE_CONFIG=$PRJROOT/config/centrifuge_bucketing.config

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

args=()
for arg in "$@"; do
  case "$arg" in
    --skip-align)
      args+=(--skip_align)
      ;;
    --skip-align=*)
      args+=("${arg/--skip-align=/--skip_align=}")
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

nextflow run "$PIPELINE_NF" \
  -c "$PIPELINE_CONFIG" \
  "${args[@]}" -resume
