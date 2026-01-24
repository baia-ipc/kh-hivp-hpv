#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
STEPSDIR=$STEPDIR/..
READSDIR="$STEPSDIR/001.0.centrifuge/output"
IDX=pave_hsa.E6

echo "==========================="
echo "SCRIPTSDIR:$SCRIPTSDIR"
echo "STEPDIR:$STEPDIR"
echo "READSDIR:$READSDIR"
echo "IDX:$IDX"
echo "==========================="

function run_pipeline {
  for RUNDIR in "$READSDIR"/*; do
    echo "RUNDIR:$RUNDIR"
    RUNID=$(basename "$RUNDIR")
    echo "RUNID:$RUNID"
    for fwd in "$RUNDIR/buckets"/*.R1.151340.fastq.gz; do
      rev="${fwd/.R1./.R2.}"
      pfx=$(basename "$fwd" | cut -f1 -d.)
      echo $SCRIPTSDIR/run.sh "$IDX" "$fwd" "$rev" "$STEPDIR/output/$RUNID/$pfx"
      $SCRIPTSDIR/run.sh "$IDX" "$fwd" "$rev" "$STEPDIR/output/$RUNID/$pfx"
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
  if [ ! -e "$STEPDIR/index/$IDX.1.bt2" ]; then
    $SCRIPTSDIR/create-index.sh
  fi
}

cd $STEPDIR
create_index
run_pipeline
aggregate_results
