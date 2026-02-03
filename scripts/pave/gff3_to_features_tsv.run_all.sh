#!/bin/bash
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <gff_dir> <out_dir>"
    exit 1
fi

GFFDIR=$1
OUTDIR=$2

mkdir -p $OUTDIR

for gff in $GFFDIR/*.gff; do
    echo "Processing $gff ..."
    PFX=$(basename $gff .gff)
    $THIS_SCRIPT_DIR/gff3_to_features_tsv.py $gff > $OUTDIR/${PFX}.tsv
done
