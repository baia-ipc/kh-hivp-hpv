#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path

from ete3 import Tree


def load_refs(refs_file: Path):
    refs = {}
    with refs_file.open("r") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            refs[parts[0]] = parts[1]
    if not refs:
        raise ValueError(f"No references loaded from {refs_file}")
    return refs


def load_outgroups(outgroups_file: Path | None):
    if outgroups_file is None:
        return set()
    outgroups = set()
    with outgroups_file.open("r") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            outgroups.add(line)
    return outgroups


def main(treefile: Path, refs_file: Path, outgroups_file: Path | None):
    refs = load_refs(refs_file)
    outgroups = load_outgroups(outgroups_file)

    # format=1 tells ete3 to keep internal node names (supports like 88/85)
    t = Tree(str(treefile), format=1)

    leaves = {leaf.name for leaf in t.iter_leaves()}

    missing_refs = [r for r in refs.values() if r not in leaves]
    if missing_refs:
        sys.stderr.write("ERROR: Missing reference tips in tree:\n")
        for r in missing_refs:
            sys.stderr.write(f"  - {r}\n")
        sys.stderr.write("\nFix tip names or update the refs file.\n")
        sys.exit(2)

    missing_out = [o for o in outgroups if o not in leaves]
    if missing_out:
        sys.stderr.write("WARNING: Missing outgroup tips in tree:\n")
        for o in missing_out:
            sys.stderr.write(f"  - {o}\n")
        sys.stderr.write("Continuing without them.\n\n")

    ref_nodes = {lin: t & name for lin, name in refs.items()}

    print("tip\tlineage\tnearest_ref\tdistance")

    for leaf in t.iter_leaves():
        name = leaf.name

        if name in outgroups:
            print(f"{name}\tOUTGROUP\t{name}\t0")
            continue

        best_lin = None
        best_ref = None
        best_dist = None

        for lin, ref_node in ref_nodes.items():
            d = t.get_distance(leaf, ref_node)
            if best_dist is None or d < best_dist:
                best_dist = d
                best_lin = lin
                best_ref = ref_node.name

        print(f"{name}\t{best_lin}\t{best_ref}\t{best_dist:.10g}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Assign lineages by distance to reference tips."
    )
    parser.add_argument("treefile", help="Input Newick tree file")
    parser.add_argument(
        "--refs-file",
        default=os.environ.get("LINEAGE_REFS"),
        help="TSV file with lineage -> reference tip IDs (or set LINEAGE_REFS)",
    )
    parser.add_argument(
        "--outgroups-file",
        default=os.environ.get("OUTGROUPS_FILE"),
        help="Optional list of outgroup tips (or set OUTGROUPS_FILE)",
    )
    args = parser.parse_args()

    if not args.refs_file:
        parser.error("refs-file is required (set --refs-file or LINEAGE_REFS).")

    outgroups_path = Path(args.outgroups_file) if args.outgroups_file else None
    main(Path(args.treefile), Path(args.refs_file), outgroups_path)
