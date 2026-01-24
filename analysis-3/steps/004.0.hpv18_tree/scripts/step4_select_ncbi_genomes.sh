#!/usr/bin/env bash
set -euo pipefail

# Prepare selected NCBI Virus genomes and rename headers with country prefix.
# This script assumes the NCBI TSV/FASTA files are already downloaded.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INPUT_DIR="$STEP_DIR/input"

NCBI_TSV="${NCBI_TSV:-$INPUT_DIR/HPV18-NCBIVirus.tsv}"
NCBI_FASTA="${NCBI_FASTA:-$INPUT_DIR/HPV18-NCBIVirus.fasta}"
ACC_COUNTRY_TSV="${ACC_COUNTRY_TSV:-$INPUT_DIR/HPV18-NCBIVirus.acc_country.tsv}"
ACC_COUNTRY_SELECTED_TSV="${ACC_COUNTRY_SELECTED_TSV:-$INPUT_DIR/HPV18-NCBIVirus.acc_country.selected.tsv}"
SELECTED_FASTA="${SELECTED_FASTA:-$INPUT_DIR/selected.fasta}"
SELECTED_RENAMED_FASTA="${SELECTED_RENAMED_FASTA:-$INPUT_DIR/selected_renamed.fasta}"
ACCESSION_COL="${ACCESSION_COL:-1}"
COUNTRY_COL="${COUNTRY_COL:-10}"
SKIP_ID="${SKIP_ID:-THAILAND/GQ180787.1}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: step4_select_ncbi_genomes.sh [--init-selection]

Creates the acc/country tables, builds selected FASTA, and renames headers.
Environment overrides:
  NCBI_TSV, NCBI_FASTA, ACC_COUNTRY_TSV, ACC_COUNTRY_SELECTED_TSV
  SELECTED_FASTA, SELECTED_RENAMED_FASTA, ACCESSION_COL, COUNTRY_COL, SKIP_ID
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

cut -f 1,10,11 "$NCBI_TSV" > "$ACC_COUNTRY_TSV"

if [[ "${1:-}" == "--init-selection" ]]; then
  cp "$ACC_COUNTRY_TSV" "$ACC_COUNTRY_SELECTED_TSV"
  echo "Created $ACC_COUNTRY_SELECTED_TSV. Edit it to select genomes, then re-run."
  exit 0
fi

if [[ ! -f "$ACC_COUNTRY_SELECTED_TSV" ]]; then
  cp "$ACC_COUNTRY_TSV" "$ACC_COUNTRY_SELECTED_TSV"
  echo "Created $ACC_COUNTRY_SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 1
fi

seqkit grep -f <(cut -f 1 "$ACC_COUNTRY_SELECTED_TSV") -r "$NCBI_FASTA" > "$SELECTED_FASTA"

python3 "$SCRIPT_DIR/rename_lineages.py" \
  "$NCBI_TSV" "$ACCESSION_COL" "$COUNTRY_COL" \
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
