#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
PRJROOT=$SCRIPTSDIR/../../..
PIPELINE_NF=$PRJROOT/pipelines/pave_gene_mapping.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/pave_gene_mapping.technical.config
USER_CONFIG=$PRJROOT/config/pave_gene_mapping.config
STEP_CONFIG=$PRJROOT/config/pave_e6.config

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
  -c "$TECH_CONFIG_COMMON" \
  -c "$TECH_CONFIG_PIPE" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  "${args[@]}"
