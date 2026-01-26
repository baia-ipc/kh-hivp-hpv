#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..
INDEXDIR=$STEPDIR/index
REFGENOMESFAS=/srv/virology/databases/pave/20240830/host_hsa/genome_fas/pave_hsa.fas

mkdir -p $INDEXDIR
cd $INDEXDIR
ln -f -s $REFGENOMESFAS .
bowtie2-build pave_hsa.fas pave_hsa

