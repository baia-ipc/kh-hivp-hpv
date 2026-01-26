#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
INDEXDIR=$STEPDIR/index

index=$INDEXDIR/virstrain

if [ $# -ne 3 ]; then
  echo "Usage: $0 <fwd> <rev> <out>"
  exit 1
fi

fwd=$1
rev=$2
out=$3

outdir=$(dirname $out)
mkdir -p $outdir

virstrain \
  -i $fwd \
  -p $rev \
  -d $index \
  -o $out
