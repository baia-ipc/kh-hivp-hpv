#!/usr/bin/env python3
"""
Compare sample E6/E7 SNPs against lineage-defining SNPs.
"""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", required=True, help="E6/E7 variants TSV")
    parser.add_argument("--lineage-snps", required=True, help="Lineage SNPs TSV")
    parser.add_argument("--output", required=True, help="Output comparison TSV")
    return parser.parse_args()


def main():
    args = parse_args()

    lineage_map = defaultdict(set)
    with open(args.lineage_snps, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        header = next(reader, None)
        if header and header[0] != "lineage":
            handle.seek(0)
            reader = csv.reader(handle, delimiter="\t")
        for row in reader:
            if len(row) < 6:
                continue
            lineage, gene, chrom, pos, ref, alt = row[:6]
            key = (gene, chrom, pos, ref, alt)
            lineage_map[key].add(lineage)

    with open(args.variants, newline="") as handle, open(args.output, "w", newline="") as out:
        reader = csv.reader(handle, delimiter="\t")
        writer = csv.writer(out, delimiter="\t")
        writer.writerow(["run", "sample", "gene", "chrom", "pos", "ref", "alt", "lineage_count", "lineages"])
        for row in reader:
            if len(row) < 8:
                continue
            run, sample, gene, chrom, pos, _id, ref, alt = row[:8]
            lineages = set()
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                lineages.update(lineage_map.get(key, set()))
            lineages_sorted = sorted(lineages)
            writer.writerow([
                run,
                sample,
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
