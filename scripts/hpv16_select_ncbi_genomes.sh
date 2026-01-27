#!/usr/bin/env bash
set -euo pipefail

# Prepare selected NCBI Virus genomes and rename headers with country prefix.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: hpv16_select_ncbi_genomes.sh [--init-selection] <ncbi_tsv> <ncbi_fasta> <selected_tsv> <selected_fasta> <selected_renamed_fasta>

Environment overrides:
  NCBI_ACC_COL, NCBI_COUNTRY_COL, SELECTED_ACC_COL, SELECTED_PREFIX_COL, SKIP_ID
EOFHELP
  exit 0
fi

init_selection=false
if [[ "${1:-}" == "--init-selection" ]]; then
  init_selection=true
  shift
fi

if [ $# -ne 5 ]; then
  echo "Error: expected 5 arguments; run with --help for usage." >&2
  exit 1
fi

NCBI_TSV=$1
NCBI_FASTA=$2
SELECTED_TSV=$3
SELECTED_FASTA=$4
SELECTED_RENAMED_FASTA=$5

NCBI_ACC_COL=${NCBI_ACC_COL:-1}
NCBI_COUNTRY_COL=${NCBI_COUNTRY_COL:-10}
SELECTED_ACC_COL=${SELECTED_ACC_COL:-1}
SELECTED_PREFIX_COL=${SELECTED_PREFIX_COL:-2}
SKIP_ID=${SKIP_ID:-}

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$NCBI_TSV" || ! -f "$NCBI_FASTA" ]]; then
  echo "Error: missing NCBI inputs: $NCBI_TSV or $NCBI_FASTA" >&2
  exit 1
fi

if [[ "$init_selection" == true ]]; then
  cut -f "$NCBI_ACC_COL","$NCBI_COUNTRY_COL" "$NCBI_TSV" > "$SELECTED_TSV"
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 0
fi

if [[ ! -f "$SELECTED_TSV" ]]; then
  cut -f "$NCBI_ACC_COL","$NCBI_COUNTRY_COL" "$NCBI_TSV" > "$SELECTED_TSV"
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 1
fi

seqkit grep -f <(cut -f 1 "$SELECTED_TSV") -r "$NCBI_FASTA" > "$SELECTED_FASTA"

python3 "$(dirname "$0")/rename_lineages.py" \
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
