#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$STEP_DIR/output"

sed 's/[a-z]/\U&/g' "$OUTPUT_DIR/all_mafft_aligned.fasta" > "$OUTPUT_DIR/all_mafft_aligned.UPPER.fasta"
trimal -in "$OUTPUT_DIR/all_mafft_aligned.UPPER.fasta" -out "$OUTPUT_DIR/all_trimal.fasta" -gt 0.90 -st 0.01
