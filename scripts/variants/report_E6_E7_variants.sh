#!/bin/bash

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <outputdir> <bed_dir> [--skip-undetermined]"
    exit 1
fi

OUTDIR=$1
BEDDIR=$2
SKIP_UNDETERMINED=false
if [ $# -eq 3 ]; then
    if [ "$3" = "--skip-undetermined" ]; then
        SKIP_UNDETERMINED=true
    else
        echo "Error: unknown option '$3'" >&2
        exit 1
    fi
fi

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
        sample_lc=$(printf '%s' "$sample" | tr '[:upper:]' '[:lower:]')
        if [ "$SKIP_UNDETERMINED" = true ] && [[ "$sample_lc" == undetermined* ]]; then
            continue
        fi
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
