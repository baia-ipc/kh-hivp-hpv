#!/usr/bin/env bash
set -euo pipefail

# Extract HPV18 reference from PAVE and build consensus sequences for samples.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$STEP_DIR/../../.." && pwd)
INPUT_DIR="$STEP_DIR/input"

PAVE_FASTA="${PAVE_FASTA:-$REPO_ROOT/analysis-input2/002.0.mapping_vs_pave/index/pave_hsa.fas}"
HPV18REF_FASTA="${HPV18REF_FASTA:-$INPUT_DIR/HPV18REF.fas}"
BCF_DIR="${BCF_DIR:-$REPO_ROOT/analysis-input2/002.0.mapping_vs_pave/output/HPV_11092024}"
OUT_DIR="${OUT_DIR:-$INPUT_DIR}"
SAMPLES="${SAMPLES:-075 213 229 237}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: step6_prepare_samples.sh

Environment overrides:
  PAVE_FASTA, HPV18REF_FASTA, BCF_DIR, OUT_DIR, SAMPLES
EOF
  exit 0
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

seqkit grep -r -p "HPV18REF.*" "$PAVE_FASTA" > "$HPV18REF_FASTA"

read -r -a sample_list <<< "$SAMPLES"
for sample in "${sample_list[@]}"; do
  bcf_path="$BCF_DIR/KHCA-$sample.bcf.gz"
  out_path="$OUT_DIR/KHCA-$sample.HPV18REF.consensus.fa"
  if [[ ! -f "$bcf_path" ]]; then
    echo "Error: missing BCF: $bcf_path" >&2
    exit 1
  fi

  bcftools consensus -f "$HPV18REF_FASTA" "$bcf_path" > "$out_path"

  tmp_out=$(mktemp)
  awk -v id="KHCA-$sample-HPV18" 'NR==1{print ">"id; next} {print}' "$out_path" > "$tmp_out"
  mv "$tmp_out" "$out_path"
done

samples_fasta="$OUT_DIR/samples.fasta"
: > "$samples_fasta"
for sample in "${sample_list[@]}"; do
  cat "$OUT_DIR/KHCA-$sample.HPV18REF.consensus.fa" >> "$samples_fasta"
done
