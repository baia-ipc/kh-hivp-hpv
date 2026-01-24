#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SCRIPTSDIR=$DIR
STEPDIR=$DIR/..
METADATA_DIR=$STEPDIR/metadata
PRJROOT=$DIR/../../../..
REPOSCRIPTS=$PRJROOT/scripts
EXTRA_ARGS=("$@")
SAMPLES_TSV=$METADATA_DIR/centrifuge_samples.tsv

function run_samples {
  if [ ! -e "$SAMPLES_TSV" ]; then
    echo "Error: $SAMPLES_TSV was not found" > /dev/stderr
    exit 1
  fi

  local last_run=""
  while IFS=$'\t' read -r run_id fastq_dir sample_id; do
    if [ -z "$run_id" ] || [[ "$run_id" == \#* ]]; then
      continue
    fi
    if [ -z "$fastq_dir" ] || [ -z "$sample_id" ]; then
      echo "Error: invalid line in $SAMPLES_TSV: $run_id $fastq_dir $sample_id" > /dev/stderr
      exit 1
    fi
    if [ "$run_id" != "$last_run" ]; then
      echo "# RUN${run_id}"
      last_run=$run_id
    fi
    echo "Run: $run_id, Sample: $sample_id"
    /usr/bin/time "$SCRIPTSDIR/run.sh" \
      "$PRJROOT/$fastq_dir/$sample_id" \
      "${EXTRA_ARGS[@]}"
  done < "$SAMPLES_TSV"
}

function aggregate_counts {
  $REPOSCRIPTS/aggregate_bucket_counts.py --skip 9606,2886930,2759 \
    --no-abs --rel-fname relative_counts.wo_human.tsv \
    $METADATA_DIR/bucket_taxonomy_ids.tsv \
    $STEPDIR/output $STEPDIR/reports
  $REPOSCRIPTS/aggregate_bucket_counts.py --skip 2886930,2759 \
    $METADATA_DIR/bucket_taxonomy_ids.tsv $STEPDIR/output $STEPDIR/reports
}

run_samples
aggregate_counts
