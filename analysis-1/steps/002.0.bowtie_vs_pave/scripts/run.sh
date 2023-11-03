#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
INDEXDIR=$STEPDIR/index

if [ $# -ne 3 ]; then
  echo "Usage: $0 <fwd> <rev> <out>"
  exit 1
fi

fwd=$1
rev=$2
out=$3

outdir=$(dirname $out)
mkdir -p $outdir
cd $outdir

function align {
  bowtie2 --all -x $INDEXDIR/pave_hsa -1 $fwd -2 $rev -S $out.sam
}

function post_alignment {
  samtools view -S -b $out.sam > $out.u.bam
  samtools sort $out.u.bam -o $out.bam
  samtools index $out.bam
  samtools idxstats $out.bam > $out.idxstats
}

function identify_top_strains {
  $SCRIPTSDIR/identify_top_strains.py $out.idxstats > $out.top_strains
}

align
post_alignment
identify_top_strains
