#!/usr/bin/env python3
import sys
from ete3 import Tree

REFS = {
    "A1": "A1/AY262282.1",
    "A2": "A2/EF202146.1",
    "A3": "A3/EF202147.1",
    "A4": "A4/EF202151.1",
    "A5": "A5/GQ180787.1",
    "B1": "B1/EF202155.1",
    "B2": "B2/KC470225.1",
    "B3": "B3/EF202152.1",
    "C1": "C1/KC470229.1",
}

OUTGROUPS = {"HPV39/M62849.1", "HPV45/X74479.1"}

def main(treefile: str):
    # format=1 tells ete3 to keep internal node names (your supports like 88/85)
    t = Tree(treefile, format=1)

    leaves = {leaf.name for leaf in t.iter_leaves()}

    # Sanity checks
    missing_refs = [r for r in REFS.values() if r not in leaves]
    if missing_refs:
        sys.stderr.write("ERROR: Missing reference tips in tree:\n")
        for r in missing_refs:
            sys.stderr.write(f"  - {r}\n")
        sys.stderr.write("\nFix tip names or update REFS in the script.\n")
        sys.exit(2)

    missing_out = [o for o in OUTGROUPS if o not in leaves]
    if missing_out:
        sys.stderr.write("WARNING: Missing outgroup tips in tree:\n")
        for o in missing_out:
            sys.stderr.write(f"  - {o}\n")
        sys.stderr.write("Continuing without them.\n\n")

    # Pre-get reference nodes
    ref_nodes = {lin: t & name for lin, name in REFS.items()}

    # Output header
    print("tip\tlineage\tnearest_ref\tdistance")

    for leaf in t.iter_leaves():
        name = leaf.name

        if name in OUTGROUPS:
            print(f"{name}\tOUTGROUP\t{name}\t0")
            continue

        # Choose the lineage whose reference has minimal patristic distance
        best_lin = None
        best_ref = None
        best_dist = None

        for lin, ref_node in ref_nodes.items():
            d = t.get_distance(leaf, ref_node)  # branch-length distance
            if best_dist is None or d < best_dist:
                best_dist = d
                best_lin = lin
                best_ref = ref_node.name

        print(f"{name}\t{best_lin}\t{best_ref}\t{best_dist:.10g}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: assign_hpv18_lineages.py <treefile.newick>\n")
        sys.exit(1)
    main(sys.argv[1])

