#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <gffdir> <tabixdir>"
    exit 2
fi
GFFDIR=$1
TABIXDIR=$2

if [ ! -d $GFFDIR ]; then
    echo "Error: $GFFDIR does not exist"
    exit 2
fi

mkdir -p $TABIXDIR
cp -R $GFFDIR/*.gff $TABIXDIR
cd $TABIXDIR
bgzip *.gff
for x in *.gff.gz; do tabix -p gff $x; done

