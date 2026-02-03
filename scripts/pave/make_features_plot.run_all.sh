#!/bin/bash
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <tsv_dir> <out_dir>"
    exit 1
fi

TSVDIR=$1
OUTDIR=$2

mkdir -p $OUTDIR

for tsv in $TSVDIR/*.tsv; do
    echo "Processing $tsv ..."
    PFX=$(basename $tsv .tsv)
    $THIS_SCRIPT_DIR/make_features_plot.py $tsv $OUTDIR/${PFX}.png
done
