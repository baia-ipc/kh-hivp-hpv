#!/usr/bin/env bash
set -euo pipefail

# Extract HPV16 reference from PAVE and build consensus sequences for samples.

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

PAVE_FASTA=${PAVE_FASTA:-}
HPV16REF_FASTA=${HPV16REF_FASTA:-}
BCF_DIR=${BCF_DIR:-}
BCF_RUN_ID=${BCF_RUN_ID:-}
TREE_CONFIG=${TREE_CONFIG:-$REPO_ROOT/config/hpv16_tree.config}
OUT_DIR=${OUT_DIR:-}
SAMPLES=${SAMPLES:-}
SAMPLES_FILE=${SAMPLES_FILE:-}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: hpv16_prepare_samples.sh

Environment overrides:
  PAVE_FASTA, HPV16REF_FASTA, BCF_DIR, BCF_RUN_ID, TREE_CONFIG
  OUT_DIR, SAMPLES, SAMPLES_FILE
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

if [[ -z "$HPV16REF_FASTA" ]]; then
  HPV16REF_FASTA="$OUT_DIR/HPV16REF.fas"
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

if [[ -z "$SAMPLES" && -f "$OUT_DIR/samples.fasta" ]]; then
  SAMPLES=$(awk -F'-' '/^>KHCA-/{print $2}' "$OUT_DIR/samples.fasta" | sort -u | xargs)
fi

if [[ -z "$SAMPLES" ]]; then
  echo "Error: SAMPLES is empty; set SAMPLES or SAMPLES_FILE." >&2
  exit 1
fi

seqkit grep -r -p "HPV16REF.*" "$PAVE_FASTA" > "$HPV16REF_FASTA"

read -r -a sample_list <<< "$SAMPLES"
for sample in "${sample_list[@]}"; do
  bcf_path="$BCF_DIR/KHCA-$sample.bcf.gz"
  out_path="$OUT_DIR/KHCA-$sample.HPV16REF.consensus.fa"
  if [[ ! -f "$bcf_path" ]]; then
    echo "Error: missing BCF: $bcf_path" >&2
    exit 1
  fi

  bcftools consensus -f "$HPV16REF_FASTA" "$bcf_path" > "$out_path"

  tmp_out=$(mktemp)
  awk -v id="KHCA-$sample-HPV16" 'NR==1{print ">"id; next} {print}' "$out_path" > "$tmp_out"
  mv "$tmp_out" "$out_path"
done

samples_fasta="$OUT_DIR/samples.fasta"
: > "$samples_fasta"
for sample in "${sample_list[@]}"; do
  cat "$OUT_DIR/KHCA-$sample.HPV16REF.consensus.fa" >> "$samples_fasta"
done
