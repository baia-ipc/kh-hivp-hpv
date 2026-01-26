#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
STEPSDIR=$STEPDIR/..
READSDIR="$STEPSDIR/001.0.centrifuge/output"

function run_pipeline {
  for RUNDIR in "$READSDIR"/*; do
    RUNID=$(basename "$RUNDIR")
    for fwd in "$RUNDIR/buckets"/*.R1.151340.fastq.gz; do
      rev="${fwd/.R1./.R2.}"
      pfx=$(basename "$fwd" | cut -f1 -d.)
      echo $SCRIPTSDIR/run.sh "$fwd" "$rev" "$STEPDIR/output/$RUNID/$pfx"
      $SCRIPTSDIR/run.sh "$fwd" "$rev" "$STEPDIR/output/$RUNID/$pfx"
    done
  done
}

function aggregate_results {
  mkdir -p "$STEPDIR/reports"
  OUTFILE="$STEPDIR/reports/strains.tsv"
  $SCRIPTSDIR/aggregate_results.py "$STEPDIR/output/" > "$OUTFILE"
}

function create_index {
  if [ ! -e "$STEPDIR/index/virstrain" ]; then
    $SCRIPTSDIR/create-index.sh
  fi
}

create_index
run_pipeline
aggregate_results
