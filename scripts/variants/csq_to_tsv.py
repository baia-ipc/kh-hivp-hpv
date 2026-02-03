#!/usr/bin/env python3
"""
Convert bcftools csq VCF output to a TSV with one row per consequence.

Usage:
  csq_to_tsv.py --run RUN --sample SAMPLE --gene GENE [--tag TAG] [--no-header]
"""

import argparse
import re
import sys


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", required=True)
    parser.add_argument("--sample", required=True)
    parser.add_argument("--gene", required=True)
    parser.add_argument("--tag", default="BCSQ", help="INFO tag produced by bcftools csq")
    parser.add_argument("--no-header", action="store_true")
    return parser.parse_args()


def parse_bcsq_format(header_line):
    # Extract "Format: ..." from the INFO description
    match = re.search(r"Format: ([^\">]+)", header_line)
    if not match:
        return []
    return [field.strip() for field in match.group(1).split("|") if field.strip()]


def parse_info(info_str):
    info = {}
    for part in info_str.split(";"):
        if "=" in part:
            key, value = part.split("=", 1)
            info[key] = value
        else:
            info[part] = True
    return info


def main():
    args = parse_args()
    bcsq_fields = []
    header_written = args.no_header

    for line in sys.stdin:
        line = line.rstrip("\n")
        if line.startswith("##INFO=<ID=" + args.tag):
            bcsq_fields = parse_bcsq_format(line)
            continue
        if line.startswith("#CHROM"):
            if not header_written:
                cols = ["run", "sample", "gene", "chrom", "pos", "ref", "alt"]
                if bcsq_fields:
                    cols += bcsq_fields
                else:
                    cols += [args.tag]
                print("\t".join(cols))
                header_written = True
            continue
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 8:
            continue
        chrom, pos, _id, ref, alt, _qual, _filt, info_str = fields[:8]
        info = parse_info(info_str)
        if args.tag not in info:
            continue
        bcsq_values = info[args.tag].split(",")
        for value in bcsq_values:
            parts = value.split("|")
            if bcsq_fields:
                # pad to header length
                if len(parts) < len(bcsq_fields):
                    parts += [""] * (len(bcsq_fields) - len(parts))
                elif len(parts) > len(bcsq_fields):
                    parts = parts[: len(bcsq_fields)]
                row = [args.run, args.sample, args.gene, chrom, pos, ref, alt] + parts
            else:
                row = [args.run, args.sample, args.gene, chrom, pos, ref, alt, value]
            print("\t".join(row))


if __name__ == "__main__":
    main()
