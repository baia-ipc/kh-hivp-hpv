#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <outputdir> <bed_dir>"
    exit 1
fi

OUTDIR=$1
BEDDIR=$2

if [ ! -d "$BEDDIR" ]; then
    echo "Error: bed directory not found: $BEDDIR" >&2
    exit 1
fi

for subdir in "$OUTDIR"/*; do
    if [ ! -d $subdir ]; then
        continue
    fi
    if [ ! -n "$(find $subdir -maxdepth 1 -name '*.bcf.gz' -print -quit)" ]; then
        continue
    fi
    runid=$(basename $subdir)
    for bcfgz in $subdir/*.bcf.gz; do
        sample=$(basename $bcfgz .bcf.gz)
        for gene in E6 E7; do
            cmd="bcftools view -R $BEDDIR/pave_hsa.$gene.bed $bcfgz -H"
            cmdout=$(eval $cmd)
            if [ -z "$cmdout" ]; then
                continue
            fi
            # split cmdout in lines and prepend each line with the runid, sample and gene
            echo "$cmdout" | awk -v runid=$runid -v sample=$sample -v gene=$gene '{print runid"\t"sample"\t"gene"\t"$0}'
        done
    done
done
