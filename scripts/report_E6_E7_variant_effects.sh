#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "Usage: $0 <outputdir> <bed_dir> <gff3_dir> <ref_fasta>" >&2
  exit 1
fi

OUTDIR=$1
BEDDIR=$2
GFFDIR=$3
REFFA=$4
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$BEDDIR" ]; then
  echo "Error: bed directory not found: $BEDDIR" >&2
  exit 1
fi
if [ ! -d "$GFFDIR" ]; then
  echo "Error: gff3 directory not found: $GFFDIR" >&2
  exit 1
fi
if [ ! -f "$REFFA" ]; then
  echo "Error: reference fasta not found: $REFFA" >&2
  exit 1
fi

tmp_gff=$(mktemp)
trap 'rm -f "$tmp_gff"' EXIT

first=true
for gff in "$GFFDIR"/*.gff "$GFFDIR"/*.gff3; do
  [ -f "$gff" ] || continue
  if $first; then
    cat "$gff" >> "$tmp_gff"
    first=false
  else
    # Avoid repeating the gff-version line
    grep -v '^##gff-version' "$gff" >> "$tmp_gff"
  fi
done

header_written=false
for subdir in "$OUTDIR"/*; do
  [ -d "$subdir" ] || continue
  if [ ! -n "$(find "$subdir" -maxdepth 1 -name '*.bcf.gz' -print -quit)" ]; then
    continue
  fi
  runid=$(basename "$subdir")
  for bcfgz in "$subdir"/*.bcf.gz; do
    [ -f "$bcfgz" ] || continue
    sample=$(basename "$bcfgz" .bcf.gz)
    for gene in E6 E7; do
      bed="$BEDDIR/pave_hsa.$gene.bed"
      [ -f "$bed" ] || continue
      if $header_written; then
        header_flag="--no-header"
      else
        header_flag=""
      fi
      bcftools view -R "$bed" "$bcfgz" -Ou | \
        bcftools csq -f "$REFFA" -g "$tmp_gff" -Ov | \
        "$SCRIPT_DIR/csq_to_tsv.py" --run "$runid" --sample "$sample" --gene "$gene" $header_flag
      header_written=true
    done
  done
done
