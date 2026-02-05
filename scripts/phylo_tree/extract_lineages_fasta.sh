#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: extract_lineages_fasta.sh <lineages_tsv> <ncbi_fasta> <output_fasta> [accession_col]

Extract lineage reference sequences from an NCBI FASTA.
EOFHELP
  exit 0
fi

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Error: expected 3 or 4 arguments; run with --help for usage." >&2
  exit 1
fi

LINEAGES_TSV=$1
NCBI_FASTA=$2
OUTPUT_FASTA=$3
ACCESSION_COL=${4:-${ACCESSION_COL:-6}}

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$LINEAGES_TSV" || ! -f "$NCBI_FASTA" ]]; then
  echo "Error: missing input files: $LINEAGES_TSV or $NCBI_FASTA" >&2
  exit 1
fi

seqkit grep -f <(cut -f "$ACCESSION_COL" "$LINEAGES_TSV") -r "$NCBI_FASTA" > "$OUTPUT_FASTA"
