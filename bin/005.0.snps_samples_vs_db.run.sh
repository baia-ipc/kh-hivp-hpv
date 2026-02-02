#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/cambodia_snps.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/cambodia_snps.config
USER_CONFIG=$PRJROOT/config/general.config
STEP_CONFIG=$PRJROOT/bin/config/targeted-analysis-hpv16-hpv18_005.snps_samples_vs_db.config

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
