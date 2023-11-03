#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SCRIPTSDIR=$DIR
STEPDIR=$DIR/..
OUTDIR=$STEPDIR/output

INDEX=/srv/giorgio/refdata/centrifuge/hpvc/hpvc
TAXDUMP=/srv/giorgio/refdata/centrifuge/factory/taxonomy-2023-10-30
BUCKETS=$STEPDIR/metadata/bucket_taxonomy_ids.tsv
HOMO_SAPIENS_TID=9606

if [ $# -ne 1 ]; then
    echo "Usage: $0 <READSETPFX>"
    exit 1
fi
READSETPFX=$1

for RDIR in R1 R2; do
    if [ `ls ${READSETPFX}*${RDIR}* | wc -l` -ne 1 ]; then
        echo -n "Error: expected exactly one file " > /dev/stderr
        echo -n "starting with $READSETPFX and " > /dev/stderr
        echo "containing _${RDIR}_ in the filename" > /dev/stderr
        echo "Found: `ls ${READSETPFX}*${RDIR}* | wc -l` files" > /dev/stderr
        exit 1
    fi
done

for PROG in centrifuge centrifuge-kreport ktImportTaxonomy \
                $SCRIPTSDIR/bucketize_fastq.py \
                $SCRIPTSDIR/assign_to_buckets.py \
                $SCRIPTSDIR/compute_lca.py; do
  if ! (which $PROG > /dev/null 2> /dev/null); then
    echo "Error: $PROG was not found" > /dev/stderr
    exit 1
  fi
done

declare -A READS
READS[R1]=$(ls ${READSETPFX}*R1*)
READS[R2]=$(ls ${READSETPFX}*R2*)

RUN=`dirname $READSETPFX`
RUN=`dirname $RUN`
RUN=`basename $RUN`
SAMPLEID=`basename $READSETPFX`

function align {
  mkdir -p $OUTDIR/$RUN/alignments
  mkdir -p $OUTDIR/$RUN/reports

  centrifuge -x $INDEX -1 ${READS[R1]} -2 ${READS[R2]} \
    -S $OUTDIR/$RUN/alignments/$SAMPLEID.aln.tsv \
    --report-file $OUTDIR/$RUN/reports/$SAMPLEID.report.tsv \
    -p 64
}

function make_kraken_style_report {
  mkdir -p $OUTDIR/$RUN/kreports

  centrifuge-kreport -x $INDEX \
    $OUTDIR/$RUN/alignments/$SAMPLEID.aln.tsv \
    > $OUTDIR/$RUN/kreports/$SAMPLEID.kreport.tsv
}

function make_krona_plots {
  mkdir -p $OUTDIR/$RUN/krona

  ktImportTaxonomy -m 6 -t 2 \
    -o $OUTDIR/$RUN/krona/$SAMPLEID.krona.html \
    $OUTDIR/$RUN/reports/$SAMPLEID.report.tsv

  mkdir -p $OUTDIR/$RUN/krona_wo_human

  awk -F'\t' -v tid="$HOMO_SAPIENS_TID" '$2 != tid {print}' \
      $OUTDIR/$RUN/reports/$SAMPLEID.report.tsv | \
    ktImportTaxonomy -m 6 -t 2 \
     -o $OUTDIR/$RUN/krona_wo_human/$SAMPLEID.krona.html -
}

function assign_to_buckets {
  mkdir -p $OUTDIR/$RUN/lca

  $SCRIPTSDIR/compute_lca.py $TAXDUMP/nodes.dmp \
    $OUTDIR/$RUN/alignments/$SAMPLEID.aln.tsv \
    $OUTDIR/$RUN/lca/$SAMPLEID.lca.tsv

  mkdir -p $OUTDIR/$RUN/bucket_assignments
  mkdir -p $OUTDIR/$RUN/bucket_sizes

  $SCRIPTSDIR/assign_to_buckets.py $TAXDUMP/nodes.dmp \
    $OUTDIR/$RUN/lca/$SAMPLEID.lca.tsv 2 \
    $OUTDIR/$RUN/bucket_assignments/$SAMPLEID.bkt.tsv \
    $(tail -n+1 $BUCKETS | cut -f 1) > \
    $OUTDIR/$RUN/bucket_sizes/$SAMPLEID.bsz.tsv
}

function split_readset_into_buckets {
  mkdir -p $OUTDIR/$RUN/buckets

  for RDIR in R1 R2; do
    $SCRIPTSDIR/bucketize_fastq.py \
      $OUTDIR/$RUN/bucket_assignments/$SAMPLEID.bkt.tsv 1 3 \
      ${READS[$RDIR]} $OUTDIR/$RUN/buckets/$SAMPLEID.$RDIR \
      --skip $HOMO_SAPIENS_TID > \
      $OUTDIR/$RUN/buckets/$SAMPLEID.$RDIR.log
  done
}

#align
#make_kraken_style_report
#make_krona_plots
assign_to_buckets
split_readset_into_buckets
