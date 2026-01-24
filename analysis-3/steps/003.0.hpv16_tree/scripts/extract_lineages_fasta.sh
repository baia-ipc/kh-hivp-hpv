#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INPUT_DIR="$STEP_DIR/input"

seqkit grep -f <(cut -f 6 "$INPUT_DIR/HPV16_lineages.tsv") -r "$INPUT_DIR/HPV16-NCBIVirus.fasta" > "$INPUT_DIR/lineages_ref.fasta"
