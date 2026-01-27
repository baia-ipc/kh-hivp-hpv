#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STEPDIR=$DIR/..
PRJROOT=$DIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/centrifuge_bucketing_all.nf
PIPELINE_CONFIG=$PRJROOT/config/centrifuge_bucketing.config
SAMPLES_TSV=$PRJROOT/metadata/samples-input2.tsv

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
  --samples_tsv "$SAMPLES_TSV" \
  --outdir "$STEPDIR/output" \
  --reports_dir "$STEPDIR/reports" \
  "${args[@]}"
