#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$STEP_DIR/output"

mafft --localpair --maxiterate 1000 --thread -1 "$OUTPUT_DIR/all.fasta" > "$OUTPUT_DIR/all_mafft_aligned.fasta"
