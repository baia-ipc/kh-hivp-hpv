#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SCRIPTSDIR=$DIR
STEPDIR=$DIR/..
METADATA_DIR=$STEPDIR/metadata
PRJROOT=$DIR/../../../..
REPOSCRIPTS=$PRJROOT/scripts

function run01 {
  echo "# RUN01"
  for samplenum in 025 029 030 037 056 064 073 075 078 082 092 098 100 103 105 117 123 133 135 136; do
    echo Run: 01, Sample: KHCA-$samplenum
     /usr/bin/time $SCRIPTSDIR/run.sh \
       $PRJROOT/input/hpv_miseq/HPV_150123_run01/Fastq/KHCA-$samplenum
  done
  for sampleid in HVP-110 Undetermined; do
    echo Run: 01, Sample: $sampleid
    /usr/bin/time $SCRIPTSDIR/run.sh \
      $PRJROOT/input/hpv_miseq/HPV_150123_run01/Fastq/$sampleid
  done
}

function run02 {
  echo "# RUN02"
  for samplenum in 116 146 147 148 149 151 152 162 164 166 168 169 172 179 181 182 186 187 191 204 213 223; do
    echo Run: 02, Sample: KHCA$samplenum
    /usr/bin/time $SCRIPTSDIR/run.sh \
      $PRJROOT/input/hpv_miseq/HPV_250523_run02/Fastq/KHCA$samplenum
  done
  for sampleid in Ex HPV019 Undetermined; do
    echo Run: 02, Sample: $sampleid
    /usr/bin/time $SCRIPTSDIR/run.sh \
      $PRJROOT/input/hpv_miseq/HPV_250523_run02/Fastq/$sampleid
  done
}

function run03 {
  echo "# RUN03"
  for samplenum in 229 230 232 233 235 236 237 255 256 263 268 285 289 298 305 306 307 322 323 328 330 332; do
    echo Run: 03, Sample: KHCA-$samplenum
    /usr/bin/time $SCRIPTSDIR/run.sh \
      ../../../input/hpv_miseq/HPV_160823_run03/Fastq/KHCA-$samplenum
  done
  for sampleid in H2O HPV019 Undetermined; do
    echo Run: 03, Sample: $sampleid
    /usr/bin/time $SCRIPTSDIR/run.sh \
      $PRJROOT/input/hpv_miseq/HPV_160823_run03/Fastq/$sampleid
  done
}

function aggregate_counts {
  $REPOSCRIPTS/aggregate_bucket_counts.py --skip 9606,2886930,2759 \
    --no-abs --rel-fname relative_counts.wo_human.tsv \
    $METADATA_DIR/bucket_taxonomy_ids.tsv \
    $STEPDIR/output $STEPDIR/reports
  $REPOSCRIPTS/aggregate_bucket_counts.py --skip 2886930,2759 \
    $METADATA_DIR/bucket_taxonomy_ids.tsv $STEPDIR/output $STEPDIR/reports
}

run01
run02
run03
aggregate_counts
