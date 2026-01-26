#!/bin/bash

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STEPDIR=$SCRIPTSDIR/..

cd $SCRIPTSDIR
INDEXDIR=../index
REFDIR=../refdata
REFNAME=pave_hsa.E6.fa
INDEXNAME=pave_hsa.E6

mkdir -p $INDEXDIR
bowtie2-build $REFDIR/$REFNAME $INDEXDIR/$INDEXNAME
