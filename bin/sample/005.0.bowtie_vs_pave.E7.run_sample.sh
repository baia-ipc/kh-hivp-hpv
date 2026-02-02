#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/pave_gene_mapping.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/pave_gene_mapping.technical.config
USER_CONFIG=$PRJROOT/config/general.config
STEP_CONFIG=$PRJROOT/bin/config/pave_e7.config

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
  -c "$TECH_CONFIG_COMMON" \
  -c "$TECH_CONFIG_PIPE" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  --read1 "$fwd" \
  --read2 "$rev" \
  --run_id "$run_id" \
  --sample_id "$sample_id" \
  "$@" -resume
