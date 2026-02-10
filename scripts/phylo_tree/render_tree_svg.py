#!/usr/bin/env python3
"""Render a Newick tree to SVG/PNG for offline viewing."""

import argparse
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from Bio import Phylo  # noqa: E402


def _tree_depths(tree):
    depths = tree.depths()
    max_depth = max(depths.values()) if depths else 0.0
    if max_depth == 0:
        depths = tree.depths(unit_branch_lengths=True)
    return depths


def _assign_angles(tree):
    tips = tree.get_terminals()
    tip_count = len(tips)
    if tip_count == 0:
        return {}

    angles = {tip: (2.0 * math.pi * idx / tip_count) for idx, tip in enumerate(tips)}

    def set_internal_angle(clade):
        if clade in angles:
            return angles[clade]
        child_angles = [set_internal_angle(child) for child in clade.clades]
        x_sum = sum(math.cos(angle) for angle in child_angles)
        y_sum = sum(math.sin(angle) for angle in child_angles)
        angle = math.atan2(y_sum, x_sum)
        if angle < 0:
            angle += 2.0 * math.pi
        angles[clade] = angle
        return angle

    set_internal_angle(tree.root)
    return angles


def _draw_arc(ax, radius, angle_a, angle_b, linewidth=0.8):
    delta = (angle_b - angle_a + math.pi) % (2.0 * math.pi) - math.pi
    n_points = max(2, int(abs(delta) * 120))
    theta = [angle_a + (delta * idx / (n_points - 1)) for idx in range(n_points)]
    radial = [radius] * n_points
    ax.plot(theta, radial, color="black", linewidth=linewidth)


def render_tree_circular(tree, svg_path, png_path=None, width=12.0, height=None):
    depths = _tree_depths(tree)
    angles = _assign_angles(tree)
    tips = tree.get_terminals()
    tip_count = len(tips)

    if tip_count == 0:
        raise ValueError("Tree has no terminal nodes")

    max_depth = max(depths.values()) if depths else 1.0
    label_radius = max_depth * 1.08
    if height is None:
        height = width

    fig = plt.figure(figsize=(width, height))
    ax = fig.add_subplot(1, 1, 1, projection="polar")
    ax.set_theta_direction(-1)
    ax.set_theta_offset(math.pi / 2.0)
    ax.set_axis_off()

    for clade in tree.find_clades(order="preorder"):
        parent_depth = depths.get(clade, 0.0)
        parent_angle = angles.get(clade, 0.0)
        for child in clade.clades:
            child_depth = depths.get(child, parent_depth)
            child_angle = angles.get(child, parent_angle)
            _draw_arc(ax, parent_depth, parent_angle, child_angle)
            ax.plot([child_angle, child_angle], [parent_depth, child_depth], color="black", linewidth=0.8)

    label_fontsize = max(4.0, min(8.0, 200.0 / tip_count))
    for tip in tips:
        angle = angles[tip]
        label = tip.name or ""
        degrees = math.degrees(angle)
        if 90.0 < degrees < 270.0:
            rotation = degrees + 180.0
            horizontal = "right"
        else:
            rotation = degrees
            horizontal = "left"
        ax.text(
            angle,
            label_radius,
            label,
            fontsize=label_fontsize,
            rotation=rotation - 90.0,
            rotation_mode="anchor",
            ha=horizontal,
            va="center",
        )

    ax.set_ylim(0.0, label_radius * 1.03)
    fig.tight_layout()
    fig.savefig(svg_path, format="svg", bbox_inches="tight")
    if png_path:
        fig.savefig(png_path, format="png", dpi=200, bbox_inches="tight")
    plt.close(fig)


def render_tree_rectangular(tree, svg_path, png_path=None, width=12.0, height=None, ladderize=True):
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
    plt.close(fig)


def render_tree(treefile, svg_path, png_path=None, width=12.0, height=None, ladderize=True, layout="circular"):
    tree = Phylo.read(treefile, "newick")
    if layout == "rectangular":
        render_tree_rectangular(
            tree=tree,
            svg_path=svg_path,
            png_path=png_path,
            width=width,
            height=height,
            ladderize=ladderize,
        )
    else:
        if ladderize:
            tree.ladderize()
        render_tree_circular(
            tree=tree,
            svg_path=svg_path,
            png_path=png_path,
            width=width,
            height=height,
        )


def main():
    parser = argparse.ArgumentParser(description="Render Newick tree to SVG/PNG.")
    parser.add_argument("--treefile", required=True, help="Input Newick tree file")
    parser.add_argument("--svg", required=True, help="Output SVG file")
    parser.add_argument("--png", help="Optional output PNG file")
    parser.add_argument("--width", type=float, default=12.0, help="Figure width in inches")
    parser.add_argument("--height", type=float, help="Figure height in inches")
    parser.add_argument("--layout", choices=["circular", "rectangular"], default="circular", help="Tree layout style")
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
        layout=args.layout,
    )


if __name__ == "__main__":
    main()
