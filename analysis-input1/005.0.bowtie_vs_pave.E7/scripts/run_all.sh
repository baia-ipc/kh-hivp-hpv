#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
PRJROOT=$SCRIPTSDIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/pave_gene_mapping.nf
PIPELINE_CONFIG=$PRJROOT/config/pave_e7.config
READSDIR="$PRJROOT/analysis-input1/001.0.centrifuge/output"

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
  -c "$PIPELINE_CONFIG" \
  --reads_dir "$READSDIR" \
  --outdir "$STEPDIR/output" \
  --reports_dir "$STEPDIR/reports" \
  --index_dir "$STEPDIR/index" \
  "${args[@]}"
