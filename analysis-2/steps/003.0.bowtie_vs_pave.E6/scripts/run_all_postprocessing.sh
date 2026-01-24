#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
OUTDIR=$STEPDIR/output

function run_computation {
  for RUNDIR in "$OUTDIR"/*; do
    RUNID=$(basename "$RUNDIR")
    for bam in "$RUNDIR"/*.bam; do
      if [[ $bam == *.u.bam ]]; then
        continue
      fi
      pfx=$(basename "$bam" | cut -f1 -d.)
      CMD="$SCRIPTSDIR/run_postprocessing.sh $bam $STEPDIR/output/$RUNID/$pfx"
      echo $CMD
      $CMD
    done
  done
}

run_computation
