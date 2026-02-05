#!/usr/bin/env bash
set -euo pipefail

# Prepare selected NCBI Virus genomes and rename headers with a prefix column.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: select_ncbi_genomes.sh [--init-selection] <ncbi_tsv> <ncbi_fasta> <selected_tsv> <selected_fasta> <selected_renamed_fasta>

Environment overrides:
  ACC_COL, SELECTION_COLS
  RENAME_TSV, RENAME_ACC_COL, RENAME_PREFIX_COL
  ACC_COUNTRY_TSV, ACC_COUNTRY_COLS
  SKIP_ID
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

ACC_COL=${ACC_COL:-1}
RENAME_TSV=${RENAME_TSV:-$SELECTED_TSV}
RENAME_ACC_COL=${RENAME_ACC_COL:-$ACC_COL}
RENAME_PREFIX_COL=${RENAME_PREFIX_COL:-2}
SELECTION_COLS=${SELECTION_COLS:-${ACC_COL},${RENAME_PREFIX_COL}}
ACC_COUNTRY_TSV=${ACC_COUNTRY_TSV:-}
ACC_COUNTRY_COLS=${ACC_COUNTRY_COLS:-1,10,11}
SKIP_ID=${SKIP_ID:-}

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$NCBI_TSV" || ! -f "$NCBI_FASTA" ]]; then
  echo "Error: missing NCBI inputs: $NCBI_TSV or $NCBI_FASTA" >&2
  exit 1
fi

if [[ -n "$ACC_COUNTRY_TSV" ]]; then
  cut -f "$ACC_COUNTRY_COLS" "$NCBI_TSV" > "$ACC_COUNTRY_TSV"
fi

if [[ "$init_selection" == true ]]; then
  if [[ -n "$ACC_COUNTRY_TSV" && -f "$ACC_COUNTRY_TSV" ]]; then
    cp "$ACC_COUNTRY_TSV" "$SELECTED_TSV"
  else
    cut -f "$SELECTION_COLS" "$NCBI_TSV" > "$SELECTED_TSV"
  fi
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 0
fi

if [[ ! -f "$SELECTED_TSV" ]]; then
  if [[ -n "$ACC_COUNTRY_TSV" && -f "$ACC_COUNTRY_TSV" ]]; then
    cp "$ACC_COUNTRY_TSV" "$SELECTED_TSV"
  else
    cut -f "$SELECTION_COLS" "$NCBI_TSV" > "$SELECTED_TSV"
  fi
  echo "Created $SELECTED_TSV. Edit it to select genomes, then re-run." >&2
  exit 1
fi

seqkit grep -f <(cut -f "$ACC_COL" "$SELECTED_TSV") -r "$NCBI_FASTA" > "$SELECTED_FASTA"

python3 "$(dirname "$0")/rename_lineages.py" \
  "$RENAME_TSV" "$RENAME_ACC_COL" "$RENAME_PREFIX_COL" \
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
