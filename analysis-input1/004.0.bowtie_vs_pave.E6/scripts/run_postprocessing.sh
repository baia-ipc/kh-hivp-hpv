#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..

if [ $# -ne 2 ]; then
  echo "Error: wrong number of parameters ($#)"
  echo "Usage: $0 <inbam> <outpfx>"
  exit 1
fi

inbam=$1
outpfx=$2

inbam=$(readlink -f $inbam)
outpfx=$(readlink -f $outpfx)

outdir=$(dirname $outpfx)
mkdir -p $outdir
cd $outdir

function check_params {
  echo "inbam=$inbam"
  if [ ! -f $inbam ]; then
    echo "ERROR: $inbam not found"
    exit 1
  fi
  echo "outpfx=$outpfx"
}

function compute_depth {
  echo samtools depth -a $inbam \> $outpfx.depth
  samtools depth -aa $inbam > $outpfx.depth
}

function compute_depth_stats {
  echo $SCRIPTSDIR/depth_stats.py $outpfx.depth $outpfx.depth.stats
  $SCRIPTSDIR/depth_stats.py $outpfx.depth $outpfx.depth.stats
}

check_params
compute_depth
compute_depth_stats
