#!/usr/bin/env python3
"""Compare query SNPs against lineage-defining SNPs."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--query-snps", required=True, help="Query SNPs TSV")
    parser.add_argument("--lineage-snps", required=True, help="Lineage SNPs TSV")
    parser.add_argument("--output", required=True, help="Output TSV")
    return parser.parse_args()


def read_snps(path, has_header=True):
    with open(path, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        rows = list(reader)
    if not rows:
        return []
    start = 1 if has_header and rows[0] and rows[0][0] in ("lineage", "cambodia_id", "query_id") else 0
    return rows[start:]


def main():
    args = parse_args()

    lineage_map = defaultdict(set)
    for row in read_snps(args.lineage_snps):
        if len(row) < 6:
            continue
        lineage, gene, chrom, pos, ref, alt = row[:6]
        key = (gene, chrom, pos, ref, alt)
        lineage_map[key].add(lineage)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "cambodia_id",
            "gene",
            "chrom",
            "pos",
            "ref",
            "alt",
            "lineage_count",
            "lineages",
        ])
        for row in read_snps(args.query_snps):
            if len(row) < 6:
                continue
            cambodia_id, gene, chrom, pos, ref, alt = row[:6]
            lineages = set()
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                lineages.update(lineage_map.get(key, set()))
            lineages_sorted = sorted(lineages)
            writer.writerow([
                cambodia_id,
                gene,
                chrom,
                pos,
                ref,
                alt,
                str(len(lineages_sorted)),
                ",".join(lineages_sorted),
            ])


if __name__ == "__main__":
    main()
