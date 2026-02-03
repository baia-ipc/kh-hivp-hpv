#!/usr/bin/env python3
"""Compare sample SNP sets against database SNP sets."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", required=True, help="Sample E6/E7 variants TSV")
    parser.add_argument("--database-snps", required=True, help="Database SNPs TSV")
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
    start = 1 if rows[0] and rows[0][0] in ("lineage", "database_id", "cambodia_id", "query_id") else 0
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
            if sample.lower().startswith("undetermined"):
                continue
            if allowed and not chrom.startswith(allowed):
                continue
            sample_id = f"{run}:{sample}"
            for alt_allele in alt.split(","):
                key = (gene, chrom, pos, ref, alt_allele)
                sample_sets[sample_id].add(key)

    database_sets = defaultdict(set)
    database_chroms = defaultdict(set)
    for row in read_query_snps(args.database_snps):
        if len(row) < 6:
            continue
        database_id, gene, chrom, pos, ref, alt = row[:6]
        for alt_allele in alt.split(","):
            key = (gene, chrom, pos, ref, alt_allele)
            database_sets[database_id].add(key)
            database_chroms[database_id].add(chrom)

    def format_snps(snps):
        items = sorted({f"{gene}:{ref}{pos}{alt}" for gene, _chrom, pos, ref, alt in snps})
        return ",".join(items)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "run",
            "sample",
            "database_id",
            "shared_snps",
            "shared_snp_ids",
            "sample_only_snps",
            "sample_only_snp_ids",
            "database_only_snps",
            "database_only_snp_ids",
            "sample_total",
            "database_total",
            "jaccard",
        ])
        for sample_id in sorted(sample_sets):
            run, sample = sample_id.split(":", 1)
            sample_set = sample_sets[sample_id]
            sample_chroms = {key[1] for key in sample_set}
            for database_id in sorted(database_sets):
                database_set = database_sets[database_id]
                if sample_chroms.isdisjoint(database_chroms[database_id]):
                    continue
                shared = sample_set & database_set
                sample_only = sample_set - database_set
                database_only = database_set - sample_set
                denom = len(sample_set) + len(database_set) - len(shared)
                jaccard = (len(shared) / denom) if denom else 0.0
                writer.writerow([
                    run,
                    sample,
                    database_id,
                    str(len(shared)),
                    format_snps(shared),
                    str(len(sample_only)),
                    format_snps(sample_only),
                    str(len(database_only)),
                    format_snps(database_only),
                    str(len(sample_set)),
                    str(len(database_set)),
                    f"{jaccard:.3f}",
                ])


if __name__ == "__main__":
    main()
