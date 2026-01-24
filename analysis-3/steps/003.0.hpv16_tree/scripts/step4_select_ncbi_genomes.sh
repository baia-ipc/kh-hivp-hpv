#!/usr/bin/env bash
set -euo pipefail

# Prepare selected NCBI Virus genomes and rename headers with country prefix.
# This script assumes the NCBI TSV/FASTA files are already downloaded.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INPUT_DIR="$STEP_DIR/input"

NCBI_TSV="${NCBI_TSV:-$INPUT_DIR/HPV16-NCBIVirus.tsv}"
NCBI_FASTA="${NCBI_FASTA:-$INPUT_DIR/HPV16-NCBIVirus.fasta}"
SELECTED_TSV="${SELECTED_TSV:-$INPUT_DIR/selected}"
SELECTED_FASTA="${SELECTED_FASTA:-$INPUT_DIR/selected.fasta}"
SELECTED_RENAMED_FASTA="${SELECTED_RENAMED_FASTA:-$INPUT_DIR/selected_renamed.fasta}"

NCBI_ACC_COL="${NCBI_ACC_COL:-1}"
NCBI_COUNTRY_COL="${NCBI_COUNTRY_COL:-10}"
SELECTED_ACC_COL="${SELECTED_ACC_COL:-1}"
SELECTED_PREFIX_COL="${SELECTED_PREFIX_COL:-2}"
SKIP_ID="${SKIP_ID:-}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: step4_select_ncbi_genomes.sh [--init-selection]

Creates the selection table from NCBI TSV, builds selected FASTA, and renames headers.
Environment overrides:
  NCBI_TSV, NCBI_FASTA, SELECTED_TSV, SELECTED_FASTA, SELECTED_RENAMED_FASTA
  NCBI_ACC_COL, NCBI_COUNTRY_COL, SELECTED_ACC_COL, SELECTED_PREFIX_COL, SKIP_ID
EOF
  exit 0
fi

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$NCBI_TSV" || ! -f "$NCBI_FASTA" ]]; then
  echo "Error: missing NCBI inputs: $NCBI_TSV or $NCBI_FASTA" >&2
  exit 1
fi

if [[ "${1:-}" == "--init-selection" ]]; then
  cut -f "$NCBI_ACC_COL","$NCBI_COUNTRY_COL" "$NCBI_TSV" > "$SELECTED_TSV"
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run."
  exit 0
fi

if [[ ! -f "$SELECTED_TSV" ]]; then
  cut -f "$NCBI_ACC_COL","$NCBI_COUNTRY_COL" "$NCBI_TSV" > "$SELECTED_TSV"
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 1
fi

seqkit grep -f <(cut -f 1 "$SELECTED_TSV") -r "$NCBI_FASTA" > "$SELECTED_FASTA"

python3 "$SCRIPT_DIR/rename_lineages.py" \
  "$SELECTED_TSV" "$SELECTED_ACC_COL" "$SELECTED_PREFIX_COL" \
  "$SELECTED_FASTA" "$SELECTED_RENAMED_FASTA"

tmp_headers=$(mktemp)
awk 'BEGIN{OFS=""} /^>/{gsub(/ /,"");} {print}' "$SELECTED_RENAMED_FASTA" > "$tmp_headers"

if [[ -n "$SKIP_ID" ]]; then
  tmp_filtered=$(mktemp)
  awk -v skip="$SKIP_ID" 'BEGIN{keep=1} /^>/{id=substr($0,2); keep=(id!=skip)} keep{print}' \
    "$tmp_headers" > "$tmp_filtered"
  mv "$tmp_filtered" "$SELECTED_RENAMED_FASTA"
  rm -f "$tmp_headers"
else
  mv "$tmp_headers" "$SELECTED_RENAMED_FASTA"
fi
