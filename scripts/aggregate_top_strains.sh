#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <output_root> <output_file>" >&2
  exit 1
fi

OUTPUT_ROOT=$1
OUTFILE=$2
header_output=false

for rundir in "$OUTPUT_ROOT"/*; do
  [ -d "$rundir" ] || continue
  runid=$(basename "$rundir")
  for topstrains in "$rundir"/*.top_strains; do
    [ -f "$topstrains" ] || continue
    if [ "$header_output" = false ]; then
      head -n 1 "$topstrains" | sed "s/^/run\t/" > "$OUTFILE"
      header_output=true
    fi
    tail -n +2 "$topstrains" | sed "s/^/$runid\t/" >> "$OUTFILE"
  done
done
