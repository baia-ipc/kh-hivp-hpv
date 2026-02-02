#!/usr/bin/env bash
set -euo pipefail

# Extract HPV18 reference from PAVE and build consensus sequences for samples.

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

PAVE_FASTA=${PAVE_FASTA:-}
HPV18REF_FASTA=${HPV18REF_FASTA:-}
BCF_DIR=${BCF_DIR:-}
BCF_RUN_ID=${BCF_RUN_ID:-}
TREE_CONFIG=${TREE_CONFIG:-$REPO_ROOT/config/hpv18_tree.config}
OUT_DIR=${OUT_DIR:-}
SAMPLES=${SAMPLES:-}
SAMPLES_FILE=${SAMPLES_FILE:-}
STRAINS_TSV=${STRAINS_TSV:-$REPO_ROOT/analysis-input2/002.0.mapping_vs_pave/reports/strains.tsv}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: hpv18_prepare_samples.sh

Environment overrides:
  PAVE_FASTA, HPV18REF_FASTA, BCF_DIR, BCF_RUN_ID, TREE_CONFIG
  OUT_DIR, SAMPLES, SAMPLES_FILE, STRAINS_TSV
EOFHELP
  exit 0
fi

if [[ -z "$PAVE_FASTA" ]]; then
PAVE_FASTA="$REPO_ROOT/refdata/raw/pave/pave_hsa.fas"
fi

if [[ -z "$OUT_DIR" ]]; then
  echo "Error: OUT_DIR is required." >&2
  exit 1
fi

if [[ -z "$HPV18REF_FASTA" ]]; then
  HPV18REF_FASTA="$OUT_DIR/HPV18REF.fas"
fi

if [[ -z "$BCF_DIR" ]]; then
  if [[ -z "$BCF_RUN_ID" && -f "$TREE_CONFIG" ]]; then
    BCF_RUN_ID=$(awk -F'=' '/bcf_run_id/ {gsub(/#.*/, "", $2); gsub(/[[:space:]]*/, "", $2); gsub(/"/, "", $2); print $2; exit}' \
      "$TREE_CONFIG")
  fi
  if [[ -n "$BCF_RUN_ID" ]]; then
    BCF_DIR="$REPO_ROOT/analysis-input2/002.0.mapping_vs_pave/output/$BCF_RUN_ID"
  fi
fi
if [[ -z "$BCF_RUN_ID" && -n "$BCF_DIR" ]]; then
  BCF_RUN_ID=$(basename "$BCF_DIR")
fi

if [[ -z "$BCF_DIR" ]]; then
  echo "Error: BCF_DIR is required (set BCF_DIR or BCF_RUN_ID, or set bcf_run_id in $TREE_CONFIG)." >&2
  exit 1
fi

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if ! command -v bcftools >/dev/null 2>&1; then
  echo "Error: bcftools is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$PAVE_FASTA" ]]; then
  echo "Error: missing PAVE FASTA: $PAVE_FASTA" >&2
  exit 1
fi

if [[ -z "$SAMPLES" && -n "$SAMPLES_FILE" ]]; then
  if [[ ! -f "$SAMPLES_FILE" ]]; then
    echo "Error: SAMPLES_FILE not found: $SAMPLES_FILE" >&2
    exit 1
  fi
  SAMPLES=$(tr '\n' ' ' < "$SAMPLES_FILE")
fi

if [[ -z "$SAMPLES" && -f "$STRAINS_TSV" && -n "$BCF_RUN_ID" ]]; then
  SAMPLES=$(awk -F'\t' -v run="$BCF_RUN_ID" 'NR>1 && $1==run && $4 ~ /(^|,)HPV18(,|$)/ {print $2}' \
    "$STRAINS_TSV" | sort -u | xargs)
fi

if [[ -z "$SAMPLES" && -f "$OUT_DIR/samples.fasta" ]]; then
  SAMPLES=$(awk -F'-' '/^>KHCA-/{print $1"-"$2}' "$OUT_DIR/samples.fasta" | sort -u | xargs)
fi

if [[ -z "$SAMPLES" ]]; then
  echo "Error: SAMPLES is empty; set SAMPLES/SAMPLES_FILE or ensure strains.tsv lists HPV18 top strains for the run." >&2
  exit 1
fi

seqkit grep -r -p "HPV18REF.*" "$PAVE_FASTA" > "$HPV18REF_FASTA"

read -r -a sample_list <<< "$SAMPLES"
for sample in "${sample_list[@]}"; do
  sample_id="$sample"
  if [[ "$sample_id" != KHCA-* ]]; then
    sample_id="KHCA-$sample_id"
  fi
  bcf_path="$BCF_DIR/${sample_id}.bcf.gz"
  out_path="$OUT_DIR/${sample_id}.HPV18REF.consensus.fa"
  if [[ ! -f "$bcf_path" ]]; then
    echo "Error: missing BCF: $bcf_path" >&2
    exit 1
  fi

  bcftools consensus -f "$HPV18REF_FASTA" "$bcf_path" > "$out_path"

  tmp_out=$(mktemp)
  awk -v id="${sample_id}-HPV18" 'NR==1{print ">"id; next} {print}' "$out_path" > "$tmp_out"
  mv "$tmp_out" "$out_path"
done

samples_fasta="$OUT_DIR/samples.fasta"
: > "$samples_fasta"
for sample in "${sample_list[@]}"; do
  sample_id="$sample"
  if [[ "$sample_id" != KHCA-* ]]; then
    sample_id="KHCA-$sample_id"
  fi
  cat "$OUT_DIR/${sample_id}.HPV18REF.consensus.fa" >> "$samples_fasta"
done
