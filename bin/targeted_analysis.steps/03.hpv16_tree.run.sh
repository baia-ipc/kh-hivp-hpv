#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
PIPELINE_NF=$PRJROOT/pipelines/phylo_tree.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/phylo_tree.config
TECH_CONFIG_STEP=$PRJROOT/config/pipelines/phylo_tree.hpv16.config
USER_CONFIG=$PRJROOT/config/user.config

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/config/analyses/targeted_analysis.config
PROFILE=targeted_hpv16_tree

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
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$PROFILE" \
  "$@" -resume
