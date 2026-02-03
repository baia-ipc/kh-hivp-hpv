#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/phylo_tree.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/phylo_tree.config
TECH_CONFIG_STEP=$PRJROOT/config/pipelines/phylo_tree.hpv18.config
USER_CONFIG=$PRJROOT/config/user.config
STEP_CONFIG=$PRJROOT/bin/config/targeted_analysis.config
PROFILE=targeted_hpv18_tree

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$TECH_CONFIG_STEP" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -profile "$PROFILE" \
  "$@" -resume
