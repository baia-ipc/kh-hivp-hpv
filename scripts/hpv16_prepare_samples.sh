#!/usr/bin/env bash
set -euo pipefail

# Extract HPV16 reference from PAVE and build consensus sequences for samples.

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

PAVE_FASTA=${PAVE_FASTA:-}
HPV16REF_FASTA=${HPV16REF_FASTA:-}
BCF_DIR=${BCF_DIR:-}
BCF_RUN_ID=${BCF_RUN_ID:-}
OUT_DIR=${OUT_DIR:-}
SAMPLES=${SAMPLES:-}
SAMPLES_FILE=${SAMPLES_FILE:-}
SAMPLES_TSV=${SAMPLES_TSV:-$REPO_ROOT/metadata/samples-input2.tsv}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: hpv16_prepare_samples.sh

Environment overrides:
  PAVE_FASTA, HPV16REF_FASTA, BCF_DIR, BCF_RUN_ID
  OUT_DIR, SAMPLES, SAMPLES_FILE, SAMPLES_TSV
EOFHELP
  exit 0
fi

if [[ -z "$PAVE_FASTA" ]]; then
PAVE_FASTA="$REPO_ROOT/refdata/pave/pave_hsa.fas"
fi

if [[ -z "$OUT_DIR" ]]; then
  echo "Error: OUT_DIR is required." >&2
  exit 1
fi

if [[ -z "$HPV16REF_FASTA" ]]; then
  HPV16REF_FASTA="$OUT_DIR/HPV16REF.fas"
fi

if [[ -z "$BCF_RUN_ID" && -z "$BCF_DIR" && -f "$SAMPLES_TSV" ]]; then
  mapfile -t run_ids < <(
    awk -F'\t' 'NR==1 && $1 ~ /^#/ {next} {
      n=split($2, parts, "/");
      last=parts[n];
      run=(tolower(last)=="fastq" && n>1) ? parts[n-1] : last;
      if (run != "") print run;
    }' "$SAMPLES_TSV" | sort -u
  )
  if [[ ${#run_ids[@]} -eq 1 ]]; then
    BCF_RUN_ID="${run_ids[0]}"
  elif [[ ${#run_ids[@]} -gt 1 ]]; then
    echo "Error: multiple run IDs in $SAMPLES_TSV; set BCF_RUN_ID or BCF_DIR explicitly." >&2
    exit 1
  fi
fi

if [[ -z "$BCF_DIR" && -n "$BCF_RUN_ID" ]]; then
  BCF_DIR="$REPO_ROOT/targeted-analysis-hpv16-hpv18/002.0.mapping_vs_pave/output/$BCF_RUN_ID"
fi

if [[ -z "$BCF_DIR" ]]; then
  echo "Error: BCF_DIR is required (set BCF_DIR or BCF_RUN_ID, or ensure $SAMPLES_TSV exists with a single run ID)." >&2
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
