#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$DIR/..
PRJROOT=$DIR/../../../..
PIPELINESDIR=$PRJROOT/pipelines
BUCKETS=$STEPDIR/metadata/bucket_taxonomy_ids.tsv
OUTDIR=$STEPDIR/output
SCRIPTS_DIR=$PRJROOT/scripts
CONDA_ENV=$PRJROOT/config/centrifuge_bucketing.env.yml
PIPELINE_NF=$PIPELINESDIR/centrifuge_bucketing.nf
PIPELINE_CONFIG=$PRJROOT/config/centrifuge_bucketing.config

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
  -c "$PIPELINE_CONFIG" \
  --reads "$READS_GLOB" \
  --outdir "$OUTDIR" \
  --buckets "$BUCKETS" \
  --scripts_dir "$SCRIPTS_DIR" \
  --conda_env "$CONDA_ENV" \
  "$@"
