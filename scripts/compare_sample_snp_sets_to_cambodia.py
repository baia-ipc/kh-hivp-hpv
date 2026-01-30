#!/usr/bin/env python3
"""Compare sample SNP sets against Cambodia SNP sets."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", required=True, help="Sample E6/E7 variants TSV")
    parser.add_argument("--cambodia-snps", required=True, help="Cambodia SNPs TSV")
    parser.add_argument("--output", required=True, help="Output TSV")
    parser.add_argument("--allow-strains", default="HPV16REF,HPV18REF",
                        help="Comma-separated strain prefixes to include [default: HPV16REF,HPV18REF]")
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
    allowed = tuple(s.strip() for s in args.allow_strains.split(",") if s.strip())

    sample_sets = defaultdict(set)
    with open(args.variants, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for row in reader:
            if len(row) < 8:
                continue
            run, sample, gene, chrom, pos, _id, ref, alt = row[:8]
            if allowed and not chrom.startswith(allowed):
                continue
            sample_id = f"{run}:{sample}"
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                sample_sets[sample_id].add(key)

    cambodia_sets = defaultdict(set)
    for row in read_query_snps(args.cambodia_snps):
        if len(row) < 6:
            continue
        cambodia_id, gene, chrom, pos, ref, alt = row[:6]
        for alt_allele in alt.split(","):
            key = (gene, chrom, pos, ref, alt_allele)
            cambodia_sets[cambodia_id].add(key)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "run",
            "sample",
            "cambodia_id",
            "shared_snps",
            "sample_only_snps",
            "cambodia_only_snps",
            "sample_total",
            "cambodia_total",
            "jaccard",
        ])
        for sample_id in sorted(sample_sets):
            run, sample = sample_id.split(":", 1)
            sample_set = sample_sets[sample_id]
            for cambodia_id in sorted(cambodia_sets):
                cambodia_set = cambodia_sets[cambodia_id]
                shared = sample_set & cambodia_set
                sample_only = sample_set - cambodia_set
                cambodia_only = cambodia_set - sample_set
                denom = len(sample_set) + len(cambodia_set) - len(shared)
                jaccard = (len(shared) / denom) if denom else 0.0
                writer.writerow([
                    run,
                    sample,
                    cambodia_id,
                    str(len(shared)),
                    str(len(sample_only)),
                    str(len(cambodia_only)),
                    str(len(sample_set)),
                    str(len(cambodia_set)),
                    f"{jaccard:.3f}",
                ])


if __name__ == "__main__":
    main()
