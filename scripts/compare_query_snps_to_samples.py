#!/usr/bin/env python3
"""Compare query SNPs against sample E6/E7 variants."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--query-snps", required=True, help="Query SNPs TSV")
    parser.add_argument("--variants", required=True, help="Sample E6/E7 variants TSV")
    parser.add_argument("--output", required=True, help="Output TSV")
    return parser.parse_args()


def read_query_snps(path):
    with open(path, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        rows = list(reader)
    if not rows:
        return []
    start = 1 if rows[0] and rows[0][0] in ("lineage", "cambodia_id", "query_id") else 0
    return rows[start:]


def main():
    args = parse_args()

    sample_map = defaultdict(set)
    with open(args.variants, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for row in reader:
            if len(row) < 8:
                continue
            run, sample, gene, chrom, pos, _id, ref, alt = row[:8]
            sample_id = f"{run}:{sample}"
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                sample_map[key].add(sample_id)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "cambodia_id",
            "gene",
            "chrom",
            "pos",
            "ref",
            "alt",
            "sample_count",
            "samples",
        ])
        for row in read_query_snps(args.query_snps):
            if len(row) < 6:
                continue
            cambodia_id, gene, chrom, pos, ref, alt = row[:6]
            samples = set()
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                samples.update(sample_map.get(key, set()))
            samples_sorted = sorted(samples)
            writer.writerow([
                cambodia_id,
                gene,
                chrom,
                pos,
                ref,
                alt,
                str(len(samples_sorted)),
                ",".join(samples_sorted),
            ])


if __name__ == "__main__":
    main()
