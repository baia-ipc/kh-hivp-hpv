#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$DIR/..
PRJROOT=$DIR/../../../..
PIPELINESDIR=$PRJROOT/pipelines
BUCKETS=$STEPDIR/metadata/bucket_taxonomy_ids.tsv
OUTDIR=$STEPDIR/output

if [ $# -ne 1 ]; then
  echo "Usage: $0 <READSETPFX>"
  exit 1
fi

READSETPFX=$1

$PIPELINESDIR/centrifuge_bucketing.sh "$READSETPFX" "$BUCKETS" "$OUTDIR"
