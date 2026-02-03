#!/bin/bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
VARIANT_PIPELINE_NF=$PRJROOT/pipelines/variant_analysis.nf
DATABASE_PIPELINE_NF=$PRJROOT/pipelines/database_snps.nf
ALL_PIPELINES_CONFIG=$PRJROOT/config/pipelines/common.config
VARIANT_PIPELINE_CONFIG=$PRJROOT/config/pipelines/variant_analysis.config
DATABASE_PIPELINE_CONFIG=$PRJROOT/config/pipelines/database_snps.config
COMBINED_MULTIQC_CONFIG=$PRJROOT/pipelines/multiqc/variant_analysis_db.multiqc.yml
USER_CONFIG=$PRJROOT/config/user.config
CONDA_MULTIQC=$PRJROOT/.conda/envs/pipeline/bin/multiqc

THREADS=$(awk -F '=' '/^[[:space:]]*threads[[:space:]]*=/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$USER_CONFIG")
THREADS=${THREADS:-24}
STEP_CONFIG=$PRJROOT/config/analyses/targeted_analysis.config
VARIANT_PROFILE=targeted_variant_analysis
DATABASE_PROFILE=targeted_variant_analysis_db
REPORTS_DIR=$PRJROOT/targeted_analysis/03.variant_analysis/reports

if ! command -v nextflow >/dev/null 2>&1; then
  echo "Error: nextflow was not found in PATH" > /dev/stderr
  exit 1
fi

args=()
resume_set=false
run_database=true
for arg in "$@"; do
  case "$arg" in
    --skip-database|--skip_database)
      run_database=false
      ;;
    *)
      args+=("$arg")
      if [ "$arg" = "-resume" ] || [ "$arg" = "--resume" ]; then
        resume_set=true
      fi
      ;;
  esac
done
if ! $resume_set; then
  args+=(-resume)
fi

nextflow run "$VARIANT_PIPELINE_NF" \
  -c "$ALL_PIPELINES_CONFIG" \
  -c "$VARIANT_PIPELINE_CONFIG" \
  -c "$USER_CONFIG" \
  -c "$STEP_CONFIG" \
  -process.maxForks "$THREADS" \
  -executor.queueSize "$THREADS" \
  -process.cpus "$THREADS" \
  -profile "$VARIANT_PROFILE" \
  "${args[@]}"

if [ "$run_database" = true ]; then
  nextflow run "$DATABASE_PIPELINE_NF" \
    -c "$ALL_PIPELINES_CONFIG" \
    -c "$DATABASE_PIPELINE_CONFIG" \
    -c "$USER_CONFIG" \
    -c "$STEP_CONFIG" \
    -process.maxForks "$THREADS" \
    -executor.queueSize "$THREADS" \
    -process.cpus "$THREADS" \
    -profile "$DATABASE_PROFILE" \
    "${args[@]}"

  db_reports_dir="$REPORTS_DIR/database_snps"
  if [ -d "$db_reports_dir" ]; then
    mv "$db_reports_dir"/* "$REPORTS_DIR"/
    rmdir "$db_reports_dir"
  fi

  if [ -x "$CONDA_MULTIQC" ]; then
    MULTIQC_BIN="$CONDA_MULTIQC"
  elif command -v multiqc >/dev/null 2>&1; then
    MULTIQC_BIN="multiqc"
  else
    echo "Error: multiqc was not found in PATH or in $CONDA_MULTIQC" > /dev/stderr
    exit 1
  fi

  "$MULTIQC_BIN" --force \
    --filename "multiqc_report.html" \
    --config "$COMBINED_MULTIQC_CONFIG" \
    --outdir "$REPORTS_DIR" \
    "$REPORTS_DIR"
fi
