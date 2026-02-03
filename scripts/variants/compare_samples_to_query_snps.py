#!/usr/bin/env python3
"""Compare sample E6/E7 SNPs against query SNPs."""
import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", required=True, help="Sample E6/E7 variants TSV")
    parser.add_argument("--query-snps", required=True, help="Query SNPs TSV")
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

    query_map = defaultdict(set)
    for row in read_query_snps(args.query_snps):
        if len(row) < 6:
            continue
        database_id, gene, chrom, pos, ref, alt = row[:6]
        for alt_allele in alt.split(","):
            key = (gene, chrom, pos, ref, alt_allele)
            query_map[key].add(database_id)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "run",
            "sample",
            "gene",
            "chrom",
            "pos",
            "ref",
            "alt",
            "database_count",
            "database_ids",
        ])
        with open(args.variants, newline="") as handle:
            reader = csv.reader(handle, delimiter="\t")
            for row in reader:
                if len(row) < 8:
                    continue
                run, sample, gene, chrom, pos, _id, ref, alt = row[:8]
                if allowed and not chrom.startswith(allowed):
                    continue
                database_ids = set()
                for alt_allele in alt.split(","):
                    key = (gene, chrom, pos, ref, alt_allele)
                    database_ids.update(query_map.get(key, set()))
                database_sorted = sorted(database_ids)
                writer.writerow([
                    run,
                    sample,
                    gene,
                    chrom,
                    pos,
                    ref,
                    alt,
                    str(len(database_sorted)),
                    ",".join(database_sorted),
                ])


if __name__ == "__main__":
    main()
