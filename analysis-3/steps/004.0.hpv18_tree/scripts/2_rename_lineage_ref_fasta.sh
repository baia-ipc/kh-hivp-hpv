#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INPUT_DIR="$STEP_DIR/input"

python3 "$SCRIPT_DIR/rename_lineages.py" \
  "$INPUT_DIR/HPV18_lineages.tsv" 6 4 \
  "$INPUT_DIR/lineages_ref.fasta" "$INPUT_DIR/lineages_ref_renamed.fasta"
