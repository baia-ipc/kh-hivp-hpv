#!/usr/bin/env bash
set -euo pipefail

# Prepare selected NCBI Virus genomes and rename headers with country prefix.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: hpv18_select_ncbi_genomes.sh [--init-selection] <ncbi_tsv> <ncbi_fasta> <acc_country_tsv> <acc_country_selected_tsv> <selected_fasta> <selected_renamed_fasta>

Environment overrides:
  ACCESSION_COL, COUNTRY_COL, SKIP_ID
EOFHELP
  exit 0
fi

init_selection=false
if [[ "${1:-}" == "--init-selection" ]]; then
  init_selection=true
  shift
fi

if [ $# -ne 6 ]; then
  echo "Error: expected 6 arguments; run with --help for usage." >&2
  exit 1
fi

NCBI_TSV=$1
NCBI_FASTA=$2
ACC_COUNTRY_TSV=$3
ACC_COUNTRY_SELECTED_TSV=$4
SELECTED_FASTA=$5
SELECTED_RENAMED_FASTA=$6

ACCESSION_COL=${ACCESSION_COL:-1}
COUNTRY_COL=${COUNTRY_COL:-10}
SKIP_ID=${SKIP_ID:-THAILAND/GQ180787.1}

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$NCBI_TSV" || ! -f "$NCBI_FASTA" ]]; then
  echo "Error: missing NCBI inputs: $NCBI_TSV or $NCBI_FASTA" >&2
  exit 1
fi

cut -f 1,10,11 "$NCBI_TSV" > "$ACC_COUNTRY_TSV"

if [[ "$init_selection" == true ]]; then
  cp "$ACC_COUNTRY_TSV" "$ACC_COUNTRY_SELECTED_TSV"
  echo "Created $ACC_COUNTRY_SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 0
fi

if [[ ! -f "$ACC_COUNTRY_SELECTED_TSV" ]]; then
  cp "$ACC_COUNTRY_TSV" "$ACC_COUNTRY_SELECTED_TSV"
  echo "Created $ACC_COUNTRY_SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 1
fi

seqkit grep -f <(cut -f 1 "$ACC_COUNTRY_SELECTED_TSV") -r "$NCBI_FASTA" > "$SELECTED_FASTA"

python3 "$(dirname "$0")/rename_lineages.py" \
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
