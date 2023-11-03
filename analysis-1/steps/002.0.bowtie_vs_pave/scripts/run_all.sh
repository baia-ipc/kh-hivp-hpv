#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
READSDIR="$STEPDIR/001.0.centrifuge/output"

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
  mkdir -p $STEPDIR/reports
  OUTFILE="$STEPDIR/reports/strains.tsv"
  header_output=false
  for RUNDIR in $STEPDIR/output/*; do
    RUNID=$(basename "$RUNDIR")
    for TOPSTRAINS in "$RUNDIR"/*.top_strains; do
      if [ "$header_output" = false ]; then
        head -n 1 "$TOPSTRAINS" | sed "s/^/run\t/" > "$OUTFILE"
        header_output=true
      fi
      tail -n +2 "$TOPSTRAINS" | sed "s/^/$RUNID\t/" >> "$OUTFILE"
    done
  done
}

function create_index {
  if [ ! -e "$STEPDIR/index/pave_hsa.1.bt2" ]; then
    $SCRIPTSDIR/create-index.sh
  fi
}

create_index
run_pipeline
aggregate_results
