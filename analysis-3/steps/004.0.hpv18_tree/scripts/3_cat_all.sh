#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INPUT_DIR="$STEP_DIR/input"
OUTPUT_DIR="$STEP_DIR/output"

cat \
  "$INPUT_DIR/selected_renamed.fasta" \
  "$INPUT_DIR/outgroups.fasta" \
  "$INPUT_DIR/lineages_ref_renamed.fasta" \
  "$INPUT_DIR/samples.fasta" \
  > "$OUTPUT_DIR/all.fasta"
