#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/bowtie_vs_pave.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/bowtie_vs_pave.technical.config
USER_CONFIG=$PRJROOT/config/bowtie_vs_pave.config
STEP_CONFIG=$PRJROOT/config/analysis-input2_002.mapping_vs_pave.config

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
