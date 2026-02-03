#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$DIR/../../.." && pwd )"
PIPELINESDIR=$PRJROOT/pipelines
PIPELINE_NF=$PIPELINESDIR/centrifuge_bucketing.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
PIPELINE_CONFIG=$PRJROOT/config/pipelines/centrifuge_bucketing.config
USER_CONFIG=$PRJROOT/config/user.config

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/config/analyses/prelim_analysis.config
PROFILE=preliminary_bucketing

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
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$PROFILE" \
  --reads "$READS_GLOB" \
  "$@" -resume
