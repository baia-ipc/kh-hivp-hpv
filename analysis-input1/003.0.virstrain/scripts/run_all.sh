#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
PRJROOT=$SCRIPTSDIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/virstrain.nf
PIPELINE_CONFIG=$PRJROOT/config/virstrain.config
READSDIR="$PRJROOT/analysis-input1/001.0.centrifuge/output"

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$PIPELINE_CONFIG" \
  --reads_dir "$READSDIR" \
  --outdir "$STEPDIR/output" \
  --reports_dir "$STEPDIR/reports" \
  --index_dir "$STEPDIR/index" \
  "$@"
