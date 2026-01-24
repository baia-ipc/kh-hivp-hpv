#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STEPDIR=$DIR/..
PRJROOT=$DIR/../../../..
SCRIPTSDIR=$PRJROOT/scripts
PIPELINESDIR=$PRJROOT/pipelines
INPUTDIR=$PRJROOT/input/HPV_11092024
METADATA_DIR=$PRJROOT/metadata/
BUCKETS=$METADATA_DIR/bucket_taxonomy_ids.tsv

function run04 {
  echo "# RUN04"
  for samplenum in 056 064 075 078 082 092 149 152 186 204 213 229 237 298 306 328; do
    echo Run: 04, Sample: KHCA-$samplenum
    /usr/bin/time $PIPELINESDIR/centrifuge_bucketing.sh \
       $INPUTDIR/Fastq/KHCA-$samplenum \
       $METADATA_DIR/bucket_taxonomy_ids.tsv \
       $STEPDIR/output
  done
  for sampleid in Undetermined; do
    echo Run: 04, Sample: $sampleid
    /usr/bin/time $PIPELINESDIR/centrifuge_bucketing.sh \
       $INPUTDIR/Fastq/$sampleid \
       $METADATA_DIR/bucket_taxonomy_ids.tsv \
       $STEPDIR/output
  done
}

function aggregate_counts {
  $SCRIPTSDIR/aggregate_bucket_counts.py --skip 9606,2886930,2759 \
    --no-abs --rel-fname relative_counts.wo_human.tsv \
    $METADATA_DIR/bucket_taxonomy_ids.tsv \
    $STEPDIR/output $STEPDIR/reports
  $SCRIPTSDIR/aggregate_bucket_counts.py --skip 2886930,2759 \
    $METADATA_DIR/bucket_taxonomy_ids.tsv $STEPDIR/output $STEPDIR/reports
}

#run04
aggregate_counts
