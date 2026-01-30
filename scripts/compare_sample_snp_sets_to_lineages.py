#!/usr/bin/env python3
"""Compare sample SNP sets against lineage SNP sets."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", required=True, help="Sample E6/E7 variants TSV")
    parser.add_argument("--lineage-snps", required=True, help="Lineage SNPs TSV")
    parser.add_argument("--output", required=True, help="Output TSV")
    parser.add_argument("--allow-strains", default="HPV16REF,HPV18REF",
                        help="Comma-separated strain prefixes to include [default: HPV16REF,HPV18REF]")
    return parser.parse_args()


def read_lineage_snps(path):
    with open(path, newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        rows = list(reader)
    if not rows:
        return []
    start = 1 if rows[0] and rows[0][0] == "lineage" else 0
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

    lineage_sets = defaultdict(set)
    for row in read_lineage_snps(args.lineage_snps):
        if len(row) < 6:
            continue
        lineage, gene, chrom, pos, ref, alt = row[:6]
        for alt_allele in alt.split(","):
            key = (gene, chrom, pos, ref, alt_allele)
            lineage_sets[lineage].add(key)

    def format_snps(snps):
        items = sorted({f"{gene}:{ref}{pos}{alt}" for gene, _chrom, pos, ref, alt in snps})
        return ",".join(items)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "run",
            "sample",
            "lineage",
            "shared_snps",
            "shared_snp_ids",
            "sample_only_snps",
            "sample_only_snp_ids",
            "lineage_only_snps",
            "lineage_only_snp_ids",
            "sample_total",
            "lineage_total",
            "jaccard",
        ])
        for sample_id in sorted(sample_sets):
            run, sample = sample_id.split(":", 1)
            sample_set = sample_sets[sample_id]
            for lineage in sorted(lineage_sets):
                lineage_set = lineage_sets[lineage]
                shared = sample_set & lineage_set
                sample_only = sample_set - lineage_set
                lineage_only = lineage_set - sample_set
                denom = len(sample_set) + len(lineage_set) - len(shared)
                jaccard = (len(shared) / denom) if denom else 0.0
                writer.writerow([
                    run,
                    sample,
                    lineage,
                    str(len(shared)),
                    format_snps(shared),
                    str(len(sample_only)),
                    format_snps(sample_only),
                    str(len(lineage_only)),
                    format_snps(lineage_only),
                    str(len(sample_set)),
                    str(len(lineage_set)),
                    f"{jaccard:.3f}",
                ])


if __name__ == "__main__":
    main()
