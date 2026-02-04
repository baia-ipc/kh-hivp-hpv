#!/usr/bin/env python3
"""Build an NCBI selection TSV from an accession list and NCBI metadata TSV."""
import argparse
from pathlib import Path


def read_accessions(path):
    accessions = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.lower().startswith("accession"):
                continue
            accessions.append(line.split()[0])
    return accessions


def main():
    parser = argparse.ArgumentParser(description="Build selected TSV for tree inputs.")
    parser.add_argument("--ncbi-tsv", required=True, help="NCBI metadata TSV")
    parser.add_argument("--selection-list", required=True, help="Accession list (one per line)")
    parser.add_argument("--columns", required=True, help="Comma-separated 1-based column indices to extract")
    parser.add_argument("--output", required=True, help="Output TSV path")
    args = parser.parse_args()

    cols = [int(c.strip()) for c in args.columns.split(",") if c.strip()]
    if not cols:
        raise ValueError("--columns must list at least one column")

    accessions = read_accessions(args.selection_list)
    if not accessions:
        raise ValueError(f"No accessions found in {args.selection_list}")

    acc_to_row = {}
    with open(args.ncbi_tsv, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            acc = parts[0] if parts else ""
            if acc:
                acc_to_row[acc] = parts

    missing = [acc for acc in accessions if acc not in acc_to_row]
    if missing:
        missing_preview = ", ".join(missing[:10])
        raise ValueError(f"Missing {len(missing)} accessions in NCBI TSV: {missing_preview}")

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as out:
        for acc in accessions:
            row = acc_to_row[acc]
            picked = []
            for col in cols:
                idx = col - 1
                picked.append(row[idx] if idx < len(row) else "")
            out.write("\t".join(picked) + "\n")


if __name__ == "__main__":
    main()
