#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$DIR/.." && pwd )"
PIPELINESDIR=$PRJROOT/pipelines
PIPELINE_NF=$PIPELINESDIR/centrifuge_bucketing.nf
TECH_CONFIG_COMMON=$PRJROOT/pipelines/config/common.technical.config
TECH_CONFIG_PIPE=$PRJROOT/pipelines/config/centrifuge_bucketing.technical.config
USER_CONFIG=$PRJROOT/config/centrifuge_bucketing.config
STEP_CONFIG=$PRJROOT/config/analysis-input1_001.centrifuge.config

if [ $# -lt 1 ]; then
  echo "Usage: $0 <READSETPFX> [nextflow args...]"
  exit 1
fi

READSETPFX=$1
shift
READSETPFX=$(cd "$(dirname "$READSETPFX")" && pwd)/$(basename "$READSETPFX")
READS_GLOB="${READSETPFX}"*_R{1,2}_*.fastq.gz
R1_GLOB="${READSETPFX}"*_R1_*.fastq.gz
R2_GLOB="${READSETPFX}"*_R2_*.fastq.gz

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

if ! compgen -G "$R1_GLOB" >/dev/null; then
  echo "Error: no R1 reads found for pattern: $R1_GLOB" > /dev/stderr
  exit 1
fi

if ! compgen -G "$R2_GLOB" >/dev/null; then
  echo "Error: no R2 reads found for pattern: $R2_GLOB" > /dev/stderr
  exit 1
fi

nextflow run "$PIPELINE_NF" \
  -c "$TECH_CONFIG_COMMON" \
  -c "$TECH_CONFIG_PIPE" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  --reads "$READS_GLOB" \
  "$@" -resume
