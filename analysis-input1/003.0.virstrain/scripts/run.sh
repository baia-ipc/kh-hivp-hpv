#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
PRJROOT=$SCRIPTSDIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/virstrain.nf
PIPELINE_CONFIG=$PRJROOT/config/virstrain.config

if [ $# -lt 3 ]; then
  echo "Usage: $0 <fwd> <rev> <out> [nextflow args...]"
  exit 1
fi

fwd=$1
rev=$2
out=$3
shift 3

run_id=$(basename "$(dirname "$out")")
sample_id=$(basename "$out")
outdir=$(dirname "$(dirname "$out")")

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$PIPELINE_CONFIG" \
  --read1 "$fwd" \
  --read2 "$rev" \
  --run_id "$run_id" \
  --sample_id "$sample_id" \
  --outdir "$outdir" \
  --reports_dir "$STEPDIR/reports" \
  --index_dir "$STEPDIR/index" \
  "$@" -resume
