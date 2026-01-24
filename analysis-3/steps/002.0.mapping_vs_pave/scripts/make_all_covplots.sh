#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <cov_stats.tsv>"
    exit 1
fi

COVSTATS=$1
STEPDIR=$SCRIPTDIR/..
STEPOUTDIR=$STEPDIR/output
TSVFILESDIR=/srv/virology/databases/pave/20240830/host_hsa/features_tsv
PLOTSOUTDIR=$STEPOUTDIR/plots

i=0
while read run_id sample strain mean_coverage_depth coverage_breadth more_info; do
  i=$((i+1))
  if [ $run_id == "run_id" ]; then continue; fi
  DEPTHFILE=$STEPOUTDIR/$run_id/$sample.depth
  if [ ! -f $DEPTHFILE ]; then
    echo "Depth file $DEPTHFILE not found"
    echo "Line $i skipped: $run_id $sample $strain $mean_coverage_depth $coverage_breadth $more_info"
    continue
  fi
  TSVFILE=$TSVFILESDIR/${strain}REF.tsv
  if [ ! -f $TSVFILE ]; then
    echo "Features TSV file $TSVFILE not found"
    echo "Line $i skipped: $run_id $sample $strain $mean_coverage_depth $coverage_breadth $more_info"
    continue
  fi
  mkdir -p $PLOTSOUTDIR/$run_id
  OUTFNAME=$PLOTSOUTDIR/${run_id}/${sample}.${strain}.png
  CMD="$SCRIPTDIR/covplot.py $DEPTHFILE ${strain}REF $TSVFILE $OUTFNAME"
  echo $CMD
  $CMD
done < $COVSTATS

