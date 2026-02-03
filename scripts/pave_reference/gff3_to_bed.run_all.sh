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
    $THIS_SCRIPT_DIR/gff3_to_bed.py $gff > $OUTDIR/${PFX}.bed
done

cd $OUTDIR
rm -f pave_hsa.bed pave_hsa.E6_E7.bed pave_hsa.E6.bed pave_hsa.E7.bed
cat *.bed > pave_hsa.bed
awk '{if ($4 == "E6" || $4 == "E7") print $0}' pave_hsa.bed > pave_hsa.E6_E7.bed
awk '{if ($4 == "E6") print $0}' pave_hsa.bed > pave_hsa.E6.bed
awk '{if ($4 == "E7") print $0}' pave_hsa.bed > pave_hsa.E7.bed
