#!/usr/bin/env python3
"""
Build lineage reference tip TSV from a lineage metadata TSV.

Output format:
  <lineage>\t<lineage>/<accession>
"""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build lineage refs TSV.")
    p.add_argument("--lineages-tsv", required=True, help="Input lineages TSV")
    p.add_argument("--output", required=True, help="Output lineage refs TSV")
    p.add_argument(
        "--lineage-col",
        type=int,
        default=4,
        help="1-based lineage column index in lineages TSV (default: 4)",
    )
    p.add_argument(
        "--accession-col",
        type=int,
        default=6,
        help="1-based accession column index in lineages TSV (default: 6)",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()
    in_path = Path(args.lineages_tsv)
    out_path = Path(args.output)

    if not in_path.is_file():
        raise SystemExit(f"Input not found: {in_path}")
    if args.lineage_col < 1 or args.accession_col < 1:
        raise SystemExit("Column indices must be >= 1")

    lineage_idx = args.lineage_col - 1
    accession_idx = args.accession_col - 1
    seen = set()
    rows = []

    with in_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            raw = line.strip()
            if not raw or raw.startswith("#"):
                continue
            cols = raw.split("\t")
            if len(cols) <= max(lineage_idx, accession_idx):
                continue
            lineage = cols[lineage_idx].strip()
            accession = cols[accession_idx].strip()
            if not lineage or not accession:
                continue
            key = (lineage, accession)
            if key in seen:
                continue
            seen.add(key)
            rows.append((lineage, f"{lineage}/{accession}"))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as out:
        for lineage, ref_tip in rows:
            out.write(f"{lineage}\t{ref_tip}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
