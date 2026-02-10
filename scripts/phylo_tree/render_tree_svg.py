#!/usr/bin/env python3
"""Render a Newick tree to SVG/PNG for offline viewing."""

import argparse
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from Bio import Phylo  # noqa: E402


def _tree_depths(tree, use_branch_lengths=False):
    if use_branch_lengths:
        depths = tree.depths()
        max_depth = max(depths.values()) if depths else 0.0
        if max_depth == 0:
            return tree.depths(unit_branch_lengths=True)
        return depths
    return tree.depths(unit_branch_lengths=True)


def _set_unit_branch_lengths(tree):
    for clade in tree.find_clades(order="preorder"):
        if clade is tree.root:
            clade.branch_length = 0.0
        else:
            clade.branch_length = 1.0


def _assign_angles(tree):
    tips = tree.get_terminals()
    tip_count = len(tips)
    if tip_count == 0:
        return {}

    tip_index = {tip: idx for idx, tip in enumerate(tips)}
    spans = {}
    angles = {}

    def set_span(clade):
        if clade in spans:
            return spans[clade]
        if clade.is_terminal():
            idx = tip_index[clade]
            spans[clade] = (idx, idx)
            return spans[clade]
        child_spans = [set_span(child) for child in clade.clades]
        lo = min(span[0] for span in child_spans)
        hi = max(span[1] for span in child_spans)
        spans[clade] = (lo, hi)
        return spans[clade]

    set_span(tree.root)
    for clade in tree.find_clades(order="postorder"):
        lo, hi = spans[clade]
        center = 0.5 * (lo + hi)
        angles[clade] = (2.0 * math.pi * center) / tip_count
    return angles


def _draw_arc(ax, radius, angle_a, angle_b, linewidth=0.8):
    # Keep arcs local to avoid long wrap-around paths through the circle.
    while angle_b - angle_a > math.pi:
        angle_b -= 2.0 * math.pi
    while angle_b - angle_a < -math.pi:
        angle_b += 2.0 * math.pi

    n_points = max(2, int(abs(angle_b - angle_a) * 120))
    theta = [angle_a + ((angle_b - angle_a) * idx / (n_points - 1)) for idx in range(n_points)]
    radial = [radius] * n_points
    ax.plot(theta, radial, color="black", linewidth=linewidth)


def _auto_circular_size(tip_count):
    # Keep label density readable for large trees while preventing oversized figures.
    return max(10.0, min(14.0, 10.0 + (0.05 * tip_count)))


def _auto_label_fontsize(tip_count):
    return max(7.5, min(12.0, 1200.0 / (tip_count + 45.0)))


def _display_label(name, max_chars):
    if max_chars is None or max_chars <= 0:
        return name
    if len(name) <= max_chars:
        return name
    keep = max(5, max_chars - 3)
    return f"{name[:keep]}..."


def _compute_label_rings(labels, tip_count, label_fontsize, base_radius):
    if tip_count <= 0:
        return 1, 0.0

    sorted_lengths = sorted(len(label) for label in labels)
    q90_idx = max(0, int(round(0.9 * (len(sorted_lengths) - 1))))
    q90_chars = max(6.0, float(sorted_lengths[q90_idx]))
    q90_label_width_pt = max(18.0, q90_chars * label_fontsize * 0.56)

    # Approximate arc length in points available per label on a single ring.
    ring_circumference_pt = 2.0 * math.pi * base_radius * 72.0
    arc_per_label_pt = ring_circumference_pt / float(tip_count)
    needed_rings = int(math.ceil(q90_label_width_pt / max(1.0, arc_per_label_pt)))
    if tip_count >= 40:
        needed_rings = max(needed_rings, 2)
    ring_count = max(1, min(6, needed_rings))
    ring_step = max(0.14, min(0.22, 0.12 + (label_fontsize * 0.008)))
    return ring_count, ring_step


def render_tree_circular(
    tree,
    svg_path,
    png_path=None,
    width=None,
    height=None,
    use_branch_lengths=False,
    label_fontsize=None,
    max_label_chars=None,
):
    depths = _tree_depths(tree, use_branch_lengths=use_branch_lengths)
    angles = _assign_angles(tree)
    tips = tree.get_terminals()
    tip_count = len(tips)

    if tip_count == 0:
        raise ValueError("Tree has no terminal nodes")

    max_depth = max(depths.values()) if depths else 1.0
    if max_depth <= 0:
        max_depth = 1.0

    if width is None:
        width = _auto_circular_size(tip_count)
    if height is None:
        height = width

    # Keep labels close enough for readability, and split dense trees on two rings.
    tree_radius = 2.0
    label_radius = 2.45
    depth_scale = tree_radius / max_depth
    scaled_depths = {clade: depth * depth_scale for clade, depth in depths.items()}

    fig = plt.figure(figsize=(width, height))
    ax = fig.add_subplot(1, 1, 1, projection="polar")
    ax.set_theta_direction(-1)
    ax.set_theta_offset(math.pi / 2.0)
    ax.set_axis_off()

    for clade in tree.find_clades(order="preorder"):
        parent_depth = scaled_depths.get(clade, 0.0)
        parent_angle = angles.get(clade, 0.0)
        for child in clade.clades:
            child_depth = scaled_depths.get(child, parent_depth)
            child_angle = angles.get(child, parent_angle)
            _draw_arc(ax, parent_depth, parent_angle, child_angle)
            ax.plot([child_angle, child_angle], [parent_depth, child_depth], color="black", linewidth=0.8)

    if label_fontsize is None:
        label_fontsize = _auto_label_fontsize(tip_count)
    labels = [_display_label((tip.name or ""), max_label_chars) for tip in tips]
    ring_count, ring_step = _compute_label_rings(labels, tip_count, label_fontsize, label_radius)
    for idx, tip in enumerate(tips):
        angle = angles[tip]
        label = labels[idx]
        ring_idx = idx % ring_count
        tip_label_radius = label_radius + (ring_idx * ring_step)
        degrees = math.degrees(angle)
        if 90.0 < degrees < 270.0:
            rotation = degrees + 180.0
            horizontal = "right"
        else:
            rotation = degrees
            horizontal = "left"
        ax.text(
            angle,
            tip_label_radius,
            label,
            fontsize=label_fontsize,
            rotation=rotation,
            rotation_mode="anchor",
            ha=horizontal,
            va="center",
        )

    ylim_max = label_radius + ((ring_count - 1) * ring_step) + 0.18
    ax.set_ylim(0.0, ylim_max)
    fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01)
    fig.savefig(svg_path, format="svg")
    if png_path:
        fig.savefig(png_path, format="png", dpi=250)
    plt.close(fig)


def render_tree_rectangular(
    tree,
    svg_path,
    png_path=None,
    width=12.0,
    height=None,
    ladderize=True,
    use_branch_lengths=False,
):
    if not use_branch_lengths:
        _set_unit_branch_lengths(tree)

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
    fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01)
    fig.savefig(svg_path, format="svg")
    if png_path:
        fig.savefig(png_path, format="png", dpi=200)
    plt.close(fig)


def render_tree(
    treefile,
    svg_path,
    png_path=None,
    width=None,
    height=None,
    ladderize=True,
    layout="circular",
    use_branch_lengths=False,
    label_fontsize=None,
    max_label_chars=None,
):
    tree = Phylo.read(treefile, "newick")
    if layout == "rectangular":
        if width is None:
            width = 12.0
        render_tree_rectangular(
            tree=tree,
            svg_path=svg_path,
            png_path=png_path,
            width=width,
            height=height,
            ladderize=ladderize,
            use_branch_lengths=use_branch_lengths,
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
            use_branch_lengths=use_branch_lengths,
            label_fontsize=label_fontsize,
            max_label_chars=max_label_chars,
        )


def main():
    parser = argparse.ArgumentParser(description="Render Newick tree to SVG/PNG.")
    parser.add_argument("--treefile", required=True, help="Input Newick tree file")
    parser.add_argument("--svg", required=True, help="Output SVG file")
    parser.add_argument("--png", help="Optional output PNG file")
    parser.add_argument("--width", type=float, help="Figure width in inches (circular default is auto)")
    parser.add_argument("--height", type=float, help="Figure height in inches")
    parser.add_argument("--layout", choices=["circular", "rectangular"], default="circular", help="Tree layout style")
    parser.add_argument("--label-fontsize", type=float, help="Force label font size in points")
    parser.add_argument(
        "--max-label-chars",
        type=int,
        default=14,
        help="Truncate labels to this many characters for readability (0 disables truncation)",
    )
    parser.add_argument("--no-ladderize", action="store_true", help="Do not ladderize the tree")
    parser.add_argument(
        "--use-branch-lengths",
        action="store_true",
        help="Use branch lengths for rendering (default: ignore lengths and use topology depth)",
    )
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
        use_branch_lengths=args.use_branch_lengths,
        label_fontsize=args.label_fontsize,
        max_label_chars=args.max_label_chars,
    )


if __name__ == "__main__":
    main()
