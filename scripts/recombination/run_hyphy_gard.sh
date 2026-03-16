#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <alignment.fasta> <gard.json> <gard.log> <model> <rate_classes> <max_breakpoints>" >&2
  exit 2
fi

alignment="$1"
out_json="$2"
log_file="$3"
model="$4"
rate_classes="$5"
max_breakpoints="$6"

: > "$log_file"

echo "[INFO] Running HyPhy GARD" >> "$log_file"
echo "[INFO] Alignment: $alignment" >> "$log_file"

tmp_dir="gard_tmp"
mkdir -p "$tmp_dir"

run_try() {
  echo "[CMD] $*" >> "$log_file"
  if "$@" >> "$log_file" 2>&1; then
    return 0
  fi
  echo "[WARN] Command failed" >> "$log_file"
  return 1
}

if ! command -v hyphy >/dev/null 2>&1; then
  echo "HyPhy executable 'hyphy' not found in PATH" >&2
  exit 127
fi

success=0
if run_try hyphy gard --alignment "$alignment" --output "$out_json" --model "$model" --rate-classes "$rate_classes" --max-breakpoints "$max_breakpoints"; then
  success=1
elif run_try hyphy gard --alignment "$alignment" --output "$out_json" --model "$model" --rate-classes "$rate_classes"; then
  success=1
elif run_try hyphy GARD --alignment "$alignment" --output "$out_json" --model "$model" --rate-classes "$rate_classes"; then
  success=1
elif run_try hyphy GARD --alignment "$alignment" --output "$out_json"; then
  success=1
fi

if [ "$success" -ne 1 ]; then
  echo "All HyPhy GARD command attempts failed. See $log_file" >&2
  exit 1
fi

if [ ! -s "$out_json" ]; then
  candidate="$(find . -maxdepth 3 -type f \( -name '*gard*.json' -o -name '*GARD*.json' -o -name '*.json' \) | head -n 1 || true)"
  if [ -n "$candidate" ]; then
    cp "$candidate" "$out_json"
    echo "[INFO] Recovered JSON output from $candidate" >> "$log_file"
  fi
fi

if [ ! -s "$out_json" ]; then
  echo "GARD completed but JSON output was not found." >&2
  exit 1
fi
