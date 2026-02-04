#!/usr/bin/env python3
"""Render a Newick tree to SVG/PNG for offline viewing."""
import argparse
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from Bio import Phylo  # noqa: E402


def render_tree(treefile, svg_path, png_path=None, width=12.0, height=None, ladderize=True):
    tree = Phylo.read(treefile, "newick")
    if ladderize:
        tree.ladderize()

    tips = tree.get_terminals()
    tip_count = len(tips)
    if height is None:
        height = max(4.0, min(40.0, 0.25 * tip_count + 2.0))

    fig = plt.figure(figsize=(width, height))
    ax = fig.add_subplot(1, 1, 1)
    ax.set_axis_off()
    Phylo.draw(tree, axes=ax, do_show=False, show_confidence=True)
    fig.tight_layout()
    fig.savefig(svg_path, format="svg", bbox_inches="tight")
    if png_path:
        fig.savefig(png_path, format="png", dpi=200, bbox_inches="tight")


def main():
    parser = argparse.ArgumentParser(description="Render Newick tree to SVG/PNG.")
    parser.add_argument("--treefile", required=True, help="Input Newick tree file")
    parser.add_argument("--svg", required=True, help="Output SVG file")
    parser.add_argument("--png", help="Optional output PNG file")
    parser.add_argument("--width", type=float, default=12.0, help="Figure width in inches")
    parser.add_argument("--height", type=float, help="Figure height in inches")
    parser.add_argument("--no-ladderize", action="store_true", help="Do not ladderize the tree")
    args = parser.parse_args()

    treefile = Path(args.treefile)
    if not treefile.exists():
        raise FileNotFoundError(f"Tree file not found: {treefile}")

    render_tree(
        treefile=treefile,
        svg_path=args.svg,
        png_path=args.png,
        width=args.width,
        height=args.height,
        ladderize=not args.no_ladderize,
    )


if __name__ == "__main__":
    main()
