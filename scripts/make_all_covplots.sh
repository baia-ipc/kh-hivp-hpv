#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <cov_stats.tsv> <depth_root> <features_tsv_dir> [plots_outdir]"
    exit 1
fi

COVSTATS=$1
DEPTHROOT=$2
TSVFILESDIR=$3
PLOTSOUTDIR=${4:-$DEPTHROOT/plots}

i=0
while read run_id sample strain mean_coverage_depth coverage_breadth more_info; do
  i=$((i+1))
  if [ $run_id == "run_id" ]; then continue; fi
  DEPTHFILE=$DEPTHROOT/$run_id/$sample.depth
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
