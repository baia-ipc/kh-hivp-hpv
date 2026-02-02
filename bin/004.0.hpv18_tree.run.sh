#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/phylo_tree.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/phylo_tree.technical.config
TECH_CONFIG_STEP=$PRJROOT/pipelines/config/phylo_tree.hpv18.technical.config
USER_CONFIG=$PRJROOT/config/phylo_tree.config
STEP_CONFIG=$PRJROOT/bin/config/analysis-input2_004.hpv18_tree.config

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$TECH_CONFIG_COMMON" \
  -c "$TECH_CONFIG_PIPE" \
  -c "$TECH_CONFIG_STEP" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  "$@" -resume
