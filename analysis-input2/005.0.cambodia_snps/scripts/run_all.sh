#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
PRJROOT=$SCRIPTSDIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/cambodia_snps.nf
PIPELINE_CONFIG=$PRJROOT/config/cambodia_snps.config
SAMPLE_VARIANTS=$PRJROOT/analysis-input2/002.0.mapping_vs_pave/reports/E6_E7_variants.tsv

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
  --sample_variants "$SAMPLE_VARIANTS" \
  --outdir "$STEPDIR/output" \
  --reports_dir "$STEPDIR/reports" \
  "${args[@]}"
