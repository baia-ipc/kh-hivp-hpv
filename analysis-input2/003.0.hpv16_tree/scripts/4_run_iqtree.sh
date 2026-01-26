#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$STEP_DIR/output"

cd "$OUTPUT_DIR"
iqtree -s all_trimal.fasta -o HPV35/M74117.1,HPV31/J04353.1,HPV33/A12360.1 -m MFP -nt AUTO -bb 1000 -alrt 1000
