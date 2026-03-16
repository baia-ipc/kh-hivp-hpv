#!/usr/bin/env python3
"""Generate pairwise identity tables/plots from an aligned FASTA."""

from __future__ import annotations

import argparse
import csv
import itertools
import sys
from pathlib import Path

from Bio import SeqIO

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--output-tsv", required=True)
    parser.add_argument("--output-png", required=True)
    parser.add_argument("--output-warnings", required=True)
    return parser.parse_args()


def pairwise_identity(seq_a: str, seq_b: str) -> tuple[float, int]:
    comparable = 0
    matches = 0
    for a, b in zip(seq_a, seq_b):
        if a == "-" or b == "-":
            continue
        comparable += 1
        if a == b:
            matches += 1
    if comparable == 0:
        return 0.0, 0
    return matches / comparable, comparable


def write_tsv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    args = parse_args()
    alignment_path = Path(args.alignment)

    records = list(SeqIO.parse(str(alignment_path), "fasta"))
    warnings: list[dict[str, str]] = []

    if len(records) < 2:
        warnings.append(
            {
                "warning_code": "insufficient_sequences",
                "message": "Need at least 2 aligned sequences to compute pairwise identity.",
            }
        )
        write_tsv(Path(args.output_tsv), [], ["sample_a", "sample_b", "identity", "comparable_sites"])
        write_tsv(Path(args.output_warnings), warnings, ["warning_code", "message"])
        fig, ax = plt.subplots(figsize=(6, 2.5))
        ax.text(0.5, 0.5, "Insufficient sequences for similarity plot", ha="center", va="center")
        ax.axis("off")
        fig.tight_layout()
        fig.savefig(args.output_png, dpi=160)
        plt.close(fig)
        return 0

    ids = [record.id for record in records]
    seqs = [str(record.seq).upper() for record in records]

    rows: list[dict[str, object]] = []
    matrix = [[1.0 for _ in ids] for _ in ids]

    for (i, id_a), (j, id_b) in itertools.combinations(enumerate(ids), 2):
        ident, comparable = pairwise_identity(seqs[i], seqs[j])
        rows.append(
            {
                "sample_a": id_a,
                "sample_b": id_b,
                "identity": round(ident, 6),
                "comparable_sites": comparable,
            }
        )
        matrix[i][j] = ident
        matrix[j][i] = ident

    write_tsv(Path(args.output_tsv), rows, ["sample_a", "sample_b", "identity", "comparable_sites"])
    write_tsv(Path(args.output_warnings), warnings, ["warning_code", "message"])

    fig_size = max(6, min(16, len(ids) * 0.45))
    fig, ax = plt.subplots(figsize=(fig_size, fig_size))
    heatmap = ax.imshow(matrix, cmap="viridis", vmin=0.0, vmax=1.0)
    ax.set_xticks(range(len(ids)))
    ax.set_yticks(range(len(ids)))
    ax.set_xticklabels(ids, rotation=90, fontsize=6)
    ax.set_yticklabels(ids, fontsize=6)
    ax.set_title("Pairwise Identity (Aligned FASTA)")
    cbar = fig.colorbar(heatmap, ax=ax, fraction=0.046, pad=0.04)
    cbar.set_label("Identity")
    fig.tight_layout()
    fig.savefig(args.output_png, dpi=180)
    plt.close(fig)
    return 0


if __name__ == "__main__":
    sys.exit(main())
