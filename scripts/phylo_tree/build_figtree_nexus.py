#!/usr/bin/env python3
"""Build a FigTree-ready annotated NEXUS from an IQ-TREE tree.

- Roots the tree on the outgroups (distance-preserving bifurcation).
- Assigns every tip a sublineage taken from the sublineage *reference* tips
  included in the tree (nearest reference by patristic distance).
- Derives a country for each tip (NCBI prefix / sample country / outgroup).
- Writes a NEXUS with per-node annotations and a FigTree block configured for:
    * rectangular (rectilinear) layout
    * branches/clades coloured by sublineage  (the sublineage "ranges")
    * external tip node-shapes (dots) coloured by country
- Also writes the rooted tree as a plain Newick file.

Sublineage references are tips whose label prefix (before '/') is one of the
sublineage codes listed in the lineages TSV.
"""
import argparse
import colorsys
from pathlib import Path

from Bio import Phylo
from Bio.Phylo.Newick import Clade


def load_sublineage_codes(lineages_tsv, sublineage_col):
    codes = []
    seen = set()
    with open(lineages_tsv, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < sublineage_col:
                continue
            code = parts[sublineage_col - 1].strip()
            if code and code.lower() not in ("sublineage", "lineage") and code not in seen:
                seen.add(code)
                codes.append(code)
    return codes


def reroot_on_outgroups(tree, outgroups):
    """Root on the outgroups, collapsing IQ-TREE's trifurcation into a clean
    bifurcation [ingroup | outgroups] while preserving branch lengths."""
    ognames = set(outgroups)
    present = [t for t in tree.get_terminals() if t.name in ognames]
    if not present:
        return False
    root = tree.root
    if len(root.clades) < 3:
        return True  # already rooted
    og_children = [c for c in root.clades if set(t.name for t in c.get_terminals()) & ognames]
    in_children = [c for c in root.clades if not (set(t.name for t in c.get_terminals()) & ognames)]
    if not og_children or not in_children:
        return False
    out_node = og_children[0] if len(og_children) == 1 else Clade(branch_length=0.0, clades=og_children)
    in_node = in_children[0] if len(in_children) == 1 else Clade(branch_length=0.0, clades=in_children)
    tree.root = Clade(clades=[in_node, out_node])
    return True


def assign_sublineages(tree, ref_tips, outgroup_names):
    """ref_tips: {tip_name: sublineage}. Returns {tip_name: sublineage} for all
    tips: references keep their own; outgroups -> 'Outgroup'; everything else ->
    sublineage of the nearest reference tip by patristic distance."""
    result = {}
    ref_clades = [t for t in tree.get_terminals() if t.name in ref_tips]
    for tip in tree.get_terminals():
        name = tip.name
        if name in ref_tips:
            result[name] = ref_tips[name]
        elif name in outgroup_names:
            result[name] = "Outgroup"
        else:
            best, best_d = None, None
            for r in ref_clades:
                d = tree.distance(tip, r)
                if best_d is None or d < best_d:
                    best, best_d = r, d
            result[name] = ref_tips[best.name] if best else "NA"
    return result


def derive_country(name, ref_tips, outgroup_names, sample_prefix, sample_country):
    if name in outgroup_names:
        return "Outgroup"
    if name in ref_tips:
        return "Reference"
    if name.startswith(sample_prefix):
        return sample_country
    if "/" in name:
        return name.split("/", 1)[0]
    return "NA"


def _hex(r, g, b):
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def sublineage_palette(sublineages):
    """Group by leading letter (major lineage) -> hue; vary lightness by the
    numeric suffix so e.g. A1..A4 are shades of one colour."""
    groups = {}
    for s in sublineages:
        letter = s[0] if s and s[0].isalpha() else "?"
        groups.setdefault(letter, []).append(s)
    letters = sorted(groups)
    hue_for = {ltr: i / max(1, len(letters)) for i, ltr in enumerate(letters)}
    colors = {}
    for ltr, subs in groups.items():
        subs_sorted = sorted(subs)
        n = len(subs_sorted)
        for i, s in enumerate(subs_sorted):
            light = 0.40 + 0.30 * (i / max(1, n - 1)) if n > 1 else 0.50
            r, g, b = colorsys.hls_to_rgb(hue_for[ltr], light, 0.75)
            colors[s] = _hex(r, g, b)
    return colors


def country_palette(countries):
    cs = [c for c in sorted(set(countries)) if c not in ("Outgroup", "Reference")]
    colors = {}
    n = len(cs)
    for i, c in enumerate(cs):
        r, g, b = colorsys.hls_to_rgb((i / max(1, n)) % 1.0, 0.50, 0.85)
        colors[c] = _hex(r, g, b)
    colors["Reference"] = "#999999"
    colors["Outgroup"] = "#000000"
    return colors


def node_sublineage(clade, tip_sub):
    """A clade's sublineage if all descendant tips share one, else None."""
    subs = {tip_sub.get(t.name) for t in clade.get_terminals()}
    subs.discard("Outgroup")
    return next(iter(subs)) if len(subs) == 1 else None


def fmt_bl(clade):
    bl = clade.branch_length
    return ":%.8f" % bl if bl is not None else ""


def write_nexus_tree(tree, tip_sub, tip_country, sub_colors, out_handle):
    def emit(clade):
        if clade.is_terminal():
            name = clade.name
            sub = tip_sub.get(name, "NA")
            country = tip_country.get(name, "NA")
            color = sub_colors.get(sub, "#000000")
            ann = '[&sublineage="%s",country="%s",!color=%s]' % (sub, country, color)
            return "%s%s%s" % (quote(name), ann, fmt_bl(clade))
        else:
            inner = ",".join(emit(c) for c in clade.clades)
            sub = node_sublineage(clade, tip_sub)
            if sub is not None:
                ann = '[&sublineage="%s",!color=%s]' % (sub, sub_colors.get(sub, "#000000"))
            else:
                ann = ""
            return "(%s)%s%s" % (inner, ann, fmt_bl(clade))

    out_handle.write("tree tree_1 = [&R] %s;\n" % emit(tree.root))


def quote(name):
    return "'%s'" % name.replace("'", "''")


def main():
    ap = argparse.ArgumentParser(description="Build FigTree NEXUS with sublineage ranges and country dots.")
    ap.add_argument("--treefile", required=True)
    ap.add_argument("--lineages-tsv", required=True)
    ap.add_argument("--sublineage-col", type=int, default=4)
    ap.add_argument("--outgroups", default="", help="Comma-separated outgroup tip labels")
    ap.add_argument("--sample-prefix", default="KHCA")
    ap.add_argument("--sample-country", default="Cambodia")
    ap.add_argument("--out-nexus", required=True)
    ap.add_argument("--rooted-treefile", help="Optional output rooted Newick")
    args = ap.parse_args()

    outgroups = [o.strip() for o in args.outgroups.split(",") if o.strip()]
    codes = set(load_sublineage_codes(args.lineages_tsv, args.sublineage_col))

    tree = Phylo.read(args.treefile, "newick")
    reroot_on_outgroups(tree, outgroups)

    # sublineage reference tips: prefix before '/' is a known sublineage code
    ref_tips = {}
    for t in tree.get_terminals():
        prefix = t.name.split("/", 1)[0]
        if prefix in codes:
            ref_tips[t.name] = prefix

    outgroup_set = set(outgroups)
    tip_sub = assign_sublineages(tree, ref_tips, outgroup_set)
    tip_country = {t.name: derive_country(t.name, ref_tips, outgroup_set, args.sample_prefix, args.sample_country)
                   for t in tree.get_terminals()}

    sub_colors = sublineage_palette(sorted(set(tip_sub.values()) - {"Outgroup"}))
    ctry_colors = country_palette(list(tip_country.values()))

    tips = tree.get_terminals()
    out = Path(args.out_nexus)
    with out.open("w", encoding="utf-8") as fh:
        fh.write("#NEXUS\n")
        fh.write("begin taxa;\n\tdimensions ntax=%d;\n\ttaxlabels\n" % len(tips))
        for t in tips:
            fh.write("\t%s[&country=\"%s\",sublineage=\"%s\"]\n"
                     % (quote(t.name), tip_country[t.name], tip_sub[t.name]))
        fh.write("\t;\nend;\n\n")
        fh.write("begin trees;\n")
        write_nexus_tree(tree, tip_sub, tip_country, sub_colors, fh)
        fh.write("end;\n\n")
        # FigTree settings block
        fh.write("begin figtree;\n")
        # Sublineage "ranges" are driven by explicit per-node !color (always
        # honoured by FigTree); country dots are attribute-driven node shapes.
        fh.write("\tset appearance.branchLineWidth=2.0;\n")
        fh.write("\tset nodeShapeExternal.isShown=true;\n")
        fh.write('\tset nodeShapeExternal.colourAttribute="country";\n')
        fh.write('\tset nodeShapeExternal.shapeType="Circle";\n')
        fh.write("\tset nodeShapeExternal.size=8.0;\n")
        fh.write("\tset tipLabels.isShown=true;\n")
        fh.write("\tset tipLabels.fontSize=9;\n")
        fh.write('\tset layout.layoutType="RECTILINEAR";\n')
        fh.write("\tset rectilinearLayout.alignTipLabels=false;\n")
        fh.write("\tset legend.isShown=true;\n")
        fh.write('\tset legend.attribute="country";\n')
        fh.write("end;\n")

    if args.rooted_treefile:
        Phylo.write(tree, args.rooted_treefile, "newick")

    # console summary
    from collections import Counter
    print("tips=%d  references=%d  sublineages=%d  countries=%d"
          % (len(tips), len(ref_tips), len(set(tip_sub.values())), len(set(tip_country.values()))))
    print("sublineage counts:", dict(Counter(tip_sub.values())))
    print("wrote", out)


if __name__ == "__main__":
    main()
