#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/virstrain.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/virstrain.config
USER_CONFIG=$PRJROOT/config/user.config
STEP_CONFIG=$PRJROOT/bin/config/preliminary-analysis-all-patients.config
PROFILE=preliminary_virstrain

if [ $# -lt 3 ]; then
  echo "Usage: $0 <fwd> <rev> <out_prefix> [nextflow args...]"
  exit 1
fi

fwd=$1
rev=$2
out=$3
shift 3

run_id=$(basename "$(dirname "$out")")
sample_id=$(basename "$out")
if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -profile "$PROFILE" \
  --read1 "$fwd" \
  --read2 "$rev" \
  --run_id "$run_id" \
  --sample_id "$sample_id" \
  "$@" -resume
