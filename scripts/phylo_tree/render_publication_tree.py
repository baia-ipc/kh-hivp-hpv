#!/usr/bin/env python3
"""
Draw a publication figure with one or more rooted trees as stacked panels.

Each panel is a rectangular phylogram drawn from the rooted tree and the tip
metadata table written by build_figtree_nexus.py:

  * outgroup tips are used for rooting only and are not drawn
  * each sublineage gets a shaded band and a label at the right margin
  * study genomes and genomes from the highlighted country are coloured
  * internal nodes with ultrafast bootstrap >= --min-support and SH-aLRT >=
    --min-alrt are labelled with SH-aLRT/UFBoot; reliable clades (SH-aLRT >= --strong-alrt and
    UFBoot >= --strong-support) are bold black, the others grey

Example:
  render_publication_tree.py \\
    --panel A HPV16 hpv16/phylo_tree.rooted.treefile hpv16/phylo_tree.metadata.tsv \\
    --panel B HPV18 hpv18/phylo_tree.rooted.treefile hpv18/phylo_tree.metadata.tsv \\
    --merge-lineages A:B,D --align-bands B \\
    --out-pdf tree.pdf --out-tiff tree.tiff
"""

from __future__ import annotations

import argparse
import csv
import sys
from io import BytesIO, StringIO
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from Bio import Phylo
from matplotlib.colors import to_rgb
from matplotlib.transforms import ScaledTranslation

from label_placement import Obstacles, place_label

# Band colours per panel title; a merged lineage is keyed by its letter.
PALETTES = {
    "HPV16": {
        "A1": "#fbd9d9", "A2": "#e9fbd9", "A3": "#d9e3fb", "A4": "#d9fafb",
        "B": "#dec3b9", "C1": "#f6d9fb", "C2": "#89e7f3", "C3": "#e3fbd9", "C4": "#89acf3",
        "D": "#85c699",
    },
    "HPV18": {
        "A1": "#e4fafc", "A2": "#fce4f6", "A3": "#e7fce4", "A4": "#e4eefc", "A5": "#fff6d5",
        "B1": "#c3ecec", "B2": "#d7d8d7", "B3": "#fbd8fe", "C1": "#ffccaa",
    },
}
FALLBACK_COLOURS = ["#fbd9d9", "#e9fbd9", "#d9e3fb", "#d9fafb", "#f6d9fb", "#fff6d5"]
LINE_WIDTH = 0.45
WEAK_SUPPORT_COLOUR = "#6e6e6e"
LEADER_FROM = 3.0  # points between node and label from which a tie line is drawn
SAMPLE_COLOUR = "#d7191c"
COUNTRY_COLOUR = "#1a1ad6"
# Panel label: points from the top left of the panel, the same in every panel,
# so that the letters of panels of different height sit on one line.
PANEL_LABEL_X = 10.0
PANEL_LABEL_DROP = 28.0  # top of the panel to the baseline shared by letter and genotype
PANEL_LABEL_INDENT = 18.0  # letter to genotype
PANEL_LETTER_SIZE = 15
PANEL_TITLE_SIZE = 9
OUTGROUP = "Outgroup"
REFERENCE = "Reference"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--panel", nargs=4, action="append", required=True,
                   metavar=("LETTER", "TITLE", "TREEFILE", "METADATA_TSV"),
                   help="One panel; repeat for several panels")
    p.add_argument("--merge-lineages", action="append", default=[], metavar="LETTER:LINEAGES",
                   help="Draw one band per lineage instead of per sublineage, e.g. A:B,D")
    p.add_argument("--align-bands", action="append", default=[], metavar="LETTER",
                   help="In this panel all bands start where the first band starts")
    p.add_argument("--min-support", type=float, default=50,
                   help="Label only nodes with ultrafast bootstrap of at least this (default: 50)")
    p.add_argument("--min-alrt", type=float, default=50,
                   help="Label only nodes with SH-aLRT of at least this; this also hides the "
                        "zero values of near-zero-length branches (default: 50)")
    p.add_argument("--support-labels", choices=["pair", "ufboot"], default="pair",
                   help="Label nodes with SH-aLRT/UFBoot pairs or with UFBoot only (default: pair)")
    p.add_argument("--strong-support", type=float, default=95,
                   help="Ultrafast bootstrap from which a clade counts as reliable (default: 95)")
    p.add_argument("--strong-alrt", type=float, default=80,
                   help="SH-aLRT from which a clade counts as reliable (default: 80)")
    p.add_argument("--sample-prefix", default="KHCA", help="Tip name prefix of study genomes")
    p.add_argument("--highlight-country", default="Cambodia")
    p.add_argument("--width-mm", type=float, default=180)
    p.add_argument("--row-mm", type=float, default=1.95, help="Height per tip")
    p.add_argument("--tip-font-size", type=float, default=4.6)
    p.add_argument("--dpi", type=int, default=600, help="TIFF resolution")
    p.add_argument("--out-pdf", help="Output PDF")
    p.add_argument("--out-tiff", help="Output TIFF (LZW-compressed)")
    return p.parse_args()


def read_metadata(path: str) -> Dict[str, Dict[str, str]]:
    with open(path, newline="") as handle:
        return {row["name"]: row for row in csv.DictReader(handle, delimiter="\t")}


def read_ingroup_tree(path: str, meta: Dict[str, Dict[str, str]]):
    """Read the rooted tree and remove the outgroup tips."""
    tree = Phylo.read(StringIO(Path(path).read_text().replace("'", "")), "newick")
    for tip in tree.get_terminals():
        if meta.get(tip.name, {}).get("sublineage") == OUTGROUP:
            tree.prune(tip)
    while len(tree.root.clades) == 1:
        tree.root = tree.root.clades[0]
    tree.root.branch_length = 0.0
    return tree


def support_values(clade) -> Tuple[Optional[float], Optional[float]]:
    """(SH-aLRT, ultrafast bootstrap) from an 'SH-aLRT/UFBoot' or plain support label."""
    label = clade.name if clade.name else clade.confidence
    if label is None or clade.is_terminal():
        return None, None
    try:
        values = [float(v) for v in str(label).split("/")]
    except ValueError:
        return None, None
    return (values[0], values[-1]) if len(values) > 1 else (None, values[0])


def layout(tree):
    """x = distance from root, y = tip row (first tip on top)."""
    x = tree.depths()
    tips = tree.get_terminals()
    y = {tip: len(tips) - 1 - i for i, tip in enumerate(tips)}
    for clade in tree.get_nonterminals(order="postorder"):
        y[clade] = (y[clade.clades[0]] + y[clade.clades[-1]]) / 2
    return x, y


def band_names(tips, meta, merged: List[str]) -> List[str]:
    """Band of each tip, in tree order.

    A run of tips that does not contain the reference genome of its own
    sublineage joins the band above it, so that every band is one block.
    """
    names = []
    for tip in tips:
        sub = meta.get(tip.name, {}).get("sublineage", "")
        names.append(sub[:1] if sub[:1] in merged else sub)
    start = 0
    for i in range(1, len(tips) + 1):
        if i < len(tips) and names[i] == names[start]:
            continue
        has_reference = any(meta.get(t.name, {}).get("country") == REFERENCE for t in tips[start:i])
        if not has_reference and start > 0:
            names[start:i] = [names[start - 1]] * (i - start)
        start = i
    return names


def band_label(name: str, tips, meta) -> str:
    if len(name) > 1:
        return name
    numbers = sorted({meta[t.name]["sublineage"][1:] for t in tips
                      if meta.get(t.name, {}).get("sublineage", "").startswith(name)})
    return f"{name}{numbers[0]}-{numbers[-1]}" if len(numbers) > 1 else name + "".join(numbers)


def draw_bands(ax, tree, x, y, meta, merged, x_right, font_size, palette, common_start):
    """Shade runs of consecutive tips that share a (sub)lineage; return the label texts.

    Each band has one colour that fades out linearly towards the right margin.
    A band starts at the crown node of its lineage, or, with common_start, all
    bands start where the first band starts.
    """
    tips = tree.get_terminals()
    names = band_names(tips, meta, merged)
    lineage_start = {}
    for letter in {n[:1] for n in names if n}:
        members = [t for t, n in zip(tips, names) if n[:1] == letter]
        lineage_start[letter] = x[tree.common_ancestor(members)] if len(members) > 1 else None
    labelled, texts, first_x0 = set(), [], None
    start = 0
    for i in range(1, len(tips) + 1):
        if i < len(tips) and names[i] == names[start]:
            continue
        name, run = names[start], tips[start:i]
        if name:
            x0 = lineage_start.get(name[:1])
            if x0 is None:
                x0 = x[tree.common_ancestor(run)] if len(run) > 1 else x[run[0]] - run[0].branch_length
            first_x0 = x0 if first_x0 is None else first_x0
            if common_start:
                x0 = first_x0
            colour = palette.get(name, FALLBACK_COLOURS[len(labelled) % len(FALLBACK_COLOURS)])
            fade = np.linspace(1.0, 0.0, 256)[None, :, None]
            rgb = np.array(to_rgb(colour))[None, None, :]
            ax.imshow(rgb * fade + (1 - fade), aspect="auto", zorder=0, interpolation="bilinear",
                      extent=(x0, x_right, y[run[-1]] - 0.5, y[run[0]] + 0.5))
            if name not in labelled:
                texts.append(ax.text(x_right, y[run[-1]] - 0.3, band_label(name, tips, meta), ha="right",
                                     va="bottom", fontsize=font_size + 0.8, fontweight="bold", zorder=4))
                labelled.add(name)
        start = i
    return texts


def to_points(ax, xd: float, yd: float):
    px = ax.transData.transform((xd, yd))
    return px * 72.0 / ax.figure.dpi


def from_points(ax, xp: float, yp: float):
    return ax.transData.inverted().transform((xp * ax.figure.dpi / 72.0, yp * ax.figure.dpi / 72.0))


def text_box(ax, text, renderer):
    box = text.get_window_extent(renderer)
    scale = 72.0 / ax.figure.dpi
    return (box.x0 * scale, box.y0 * scale, box.x1 * scale, box.y1 * scale)


def draw_branches(ax, tree, x, y, obstacles):
    line = dict(color="black", linewidth=LINE_WIDTH, solid_capstyle="projecting", zorder=2)
    segments = [((-0.004 * max(x.values()), y[tree.root]), (0.0, y[tree.root]))]
    for clade in tree.find_clades():
        for child in clade.clades:
            segments.append(((x[clade], y[clade]), (x[clade], y[child])))
            segments.append(((x[clade], y[child]), (x[child], y[child])))
    for (xa, ya), (xb, yb) in segments:
        ax.plot([xa, xb], [ya, yb], **line)
        obstacles.add_segment(*to_points(ax, xa, ya), *to_points(ax, xb, yb), width=LINE_WIDTH)


def draw_tips(ax, tree, x, y, meta, args, obstacles, renderer):
    for tip in tree.get_terminals():
        colour = "black"
        if tip.name.startswith(args.sample_prefix):
            colour = SAMPLE_COLOUR
        elif meta.get(tip.name, {}).get("country") == args.highlight_country:
            colour = COUNTRY_COLOUR
        ax.plot(x[tip], y[tip], "o", markersize=1.3, color="black", zorder=3)
        tx, ty = to_points(ax, x[tip], y[tip])
        obstacles.add_box((tx - 0.8, ty - 0.8, tx + 0.8, ty + 0.8))
        label = ax.annotate(tip.name, (x[tip], y[tip]), xytext=(2.5, 0), textcoords="offset points",
                            va="center", fontsize=args.tip_font_size, color=colour, zorder=3)
        obstacles.add_box(text_box(ax, label, renderer))


def text_width(text: str, size: float, bold: bool) -> float:
    """Width in points of a label made of digits and '/' in DejaVu Sans."""
    digit, slash = (0.70, 0.37) if bold else (0.64, 0.34)
    return size * sum(slash if ch == "/" else digit for ch in text)


def draw_support(ax, tree, x, y, args, obstacles) -> int:
    """Label nodes with branch support; return how many labels found no free place.

    A label is shown when the ultrafast bootstrap reaches --min-support and
    the SH-aLRT, if present, reaches --min-alrt. It is
    bold black when the clade is reliable (ultrafast bootstrap >= --strong-support
    and, if present, SH-aLRT >= --strong-alrt) and grey otherwise. A label that
    only fits away from its node is tied to it with a thin line.
    """
    size = args.tip_font_size - 1.3
    height = 0.74 * size
    parent = {child: clade for clade in tree.find_clades() for child in clade.clades}
    support = {c: support_values(c) for c in tree.get_nonterminals() if c is not tree.root}
    labelled = [c for c, (alrt, ufb) in support.items()
                if ufb is not None and ufb >= args.min_support
                and (alrt is None or alrt >= args.min_alrt)]
    unplaced = 0
    for clade in sorted(labelled, key=lambda c: x[c] - x[parent[c]]):  # shortest branches first
        alrt, ufb = support[clade]
        pair = args.support_labels == "pair" and alrt is not None
        text = f"{alrt:.0f}/{ufb:.0f}" if pair else f"{ufb:.0f}"
        strong = ufb >= args.strong_support and (alrt is None or alrt >= args.strong_alrt)
        width = text_width(text, size, strong)
        nx, ny = to_points(ax, x[clade], y[clade])
        stem = nx - to_points(ax, x[parent[clade]], y[clade])[0]
        spot = place_label(obstacles, nx, ny, stem, width, height)
        if spot is None:
            unplaced += 1
            spot = (nx - 0.7 - width, ny + 0.7)
        colour = "black" if strong else WEAK_SUPPORT_COLOUR
        xd, yd = from_points(ax, *spot)
        ax.text(xd, yd, text, ha="left", va="baseline", fontsize=size, zorder=3,
                color=colour, fontweight="bold" if strong else "normal")
        # nearest point of the label box to the node
        px = min(max(nx, spot[0]), spot[0] + width)
        py = min(max(ny, spot[1]), spot[1] + height)
        if ((px - nx) ** 2 + (py - ny) ** 2) ** 0.5 > LEADER_FROM:
            ax.plot(*zip(from_points(ax, nx, ny), from_points(ax, px, py)),
                    color=WEAK_SUPPORT_COLOUR, linewidth=0.2, zorder=2.5)
    return unplaced


def draw_scale_bar(ax, x_max, font_size):
    length = 10 ** np.floor(np.log10(x_max / 4))
    ax.plot([0, length], [-1.6, -1.6], color="black", linewidth=0.6)
    ax.text(length / 2, -2.0, f"{length:g}", ha="center", va="top", fontsize=font_size - 0.6)


def draw_panel_label(ax, letter, title):
    """Panel letter and genotype, on one baseline a fixed distance below the panel top.

    Offsets are in points rather than axes fractions, so panels of different
    height carry their label in the same place.
    """
    def anchor(dx: float):
        return ax.transAxes + ScaledTranslation(dx / 72.0, -PANEL_LABEL_DROP / 72.0,
                                                ax.figure.dpi_scale_trans)

    return (ax.text(0, 1, letter, transform=anchor(PANEL_LABEL_X), fontsize=PANEL_LETTER_SIZE,
                    fontweight="bold", ha="left", va="baseline"),
            ax.text(0, 1, f"({title})", transform=anchor(PANEL_LABEL_X + PANEL_LABEL_INDENT),
                    fontsize=PANEL_TITLE_SIZE, ha="left", va="baseline"))


def draw_panel(ax, letter, title, treefile, metadata_tsv, merged, args) -> int:
    meta = read_metadata(metadata_tsv)
    tree = read_ingroup_tree(treefile, meta)
    x, y = layout(tree)
    n_tips, x_max = len(tree.get_terminals()), max(x.values())
    x_right = x_max * 1.22
    ax.set_xlim(-0.01 * x_max, x_right)
    ax.set_ylim(-3.2, n_tips - 0.3)
    ax.axis("off")
    renderer = ax.figure.canvas.get_renderer()
    obstacles = Obstacles()
    palette = PALETTES.get(title, {})
    for text in draw_bands(ax, tree, x, y, meta, merged, x_right, args.tip_font_size, palette,
                           letter in args.align_bands):
        obstacles.add_box(text_box(ax, text, renderer))
    draw_branches(ax, tree, x, y, obstacles)
    draw_tips(ax, tree, x, y, meta, args, obstacles, renderer)
    draw_scale_bar(ax, x_max, args.tip_font_size)
    for text in draw_panel_label(ax, letter, title):
        box = text_box(ax, text, renderer)
        if not obstacles.is_free(box):
            print(f"Warning: the label of panel {letter} overlaps the tree", file=sys.stderr)
        obstacles.add_box(box)
    return draw_support(ax, tree, x, y, args, obstacles)


def save_rgb_tiff(fig, path: str, dpi: int) -> None:
    """Write an LZW-compressed RGB TIFF (white background, no alpha channel)."""
    from PIL import Image

    buffer = BytesIO()
    fig.savefig(buffer, format="png", dpi=dpi, facecolor="white")
    buffer.seek(0)
    Image.MAX_IMAGE_PIXELS = None
    Image.open(buffer).convert("RGB").save(path, compression="tiff_lzw", dpi=(dpi, dpi))


def main() -> int:
    args = parse_args()
    if not (args.out_pdf or args.out_tiff):
        raise SystemExit("Give --out-pdf and/or --out-tiff")
    merged = {}
    for spec in args.merge_lineages:
        letter, _, lineages = spec.partition(":")
        merged[letter] = [s.strip() for s in lineages.split(",") if s.strip()]
    metas = [read_metadata(p[3]) for p in args.panel]
    rows = [sum(1 for r in m.values() if r.get("sublineage") != OUTGROUP) + 3.5 for m in metas]
    mm = 1 / 25.4
    plt.rcParams.update({"font.family": "DejaVu Sans", "pdf.fonttype": 42})
    fig, axes = plt.subplots(len(args.panel), 1, squeeze=False,
                             figsize=(args.width_mm * mm, sum(rows) * args.row_mm * mm),
                             gridspec_kw={"height_ratios": rows, "hspace": 0.03})
    fig.subplots_adjust(left=0.01, right=0.995, top=0.995, bottom=0.005)
    unplaced = 0
    for ax, (letter, title, treefile, metadata_tsv) in zip(axes[:, 0], args.panel):
        unplaced += draw_panel(ax, letter, title, treefile, metadata_tsv, merged.get(letter, []), args)
    if unplaced:
        print(f"Warning: {unplaced} support labels found no free place and may touch a line",
              file=sys.stderr)
    if args.out_pdf:
        fig.savefig(args.out_pdf, dpi=args.dpi)
    if args.out_tiff:
        save_rgb_tiff(fig, args.out_tiff, args.dpi)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
