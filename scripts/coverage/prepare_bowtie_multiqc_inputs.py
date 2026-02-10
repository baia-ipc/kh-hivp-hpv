#!/usr/bin/env python
import argparse
import csv
import os


def format_breadth_value(value):
    value = value.strip()
    if not value or value.upper() == "NA":
        return value
    if value.endswith("%"):
        return value
    try:
        breadth = float(value)
    except ValueError:
        return value
    pct = breadth * 100.0
    if 0 < pct < 1:
        return "< 1%"
    return f"{int(round(pct))}%"


def format_covstats_row(header, row):
    formatted = list(row)
    for idx, colname in enumerate(header):
        if idx >= len(formatted):
            break
        if colname.endswith("breadth"):
            formatted[idx] = format_breadth_value(formatted[idx])
    return formatted


def is_undetermined(row):
    if not row or len(row) < 2:
        return False
    sample = row[1]
    return sample.startswith("Undetermined")


def build_covstats_id(row):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    strain = row[2] if len(row) > 2 else ""
    return f"{run}:{sample}:{strain}"


def rewrite_with_header(src, dest, id_builder=None, skip_undetermined=False, row_formatter=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        header = next(reader, None)
        if not header:
            return
        writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            if skip_undetermined and is_undetermined(row):
                continue
            if row_formatter:
                row = row_formatter(header, row)
            if id_builder:
                sample = id_builder(row)
            else:
                sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare bowtie_vs_pave tables for MultiQC.")
    parser.add_argument('--strains', required=True)
    parser.add_argument('--strains-out', required=True)
    parser.add_argument('--cov-stats', required=True)
    parser.add_argument('--cov-stats-out', required=True)
    parser.add_argument('--cov-stats-filtered', required=True)
    parser.add_argument('--cov-stats-filtered-out', required=True)
    parser.add_argument('--coverage', required=True)
    parser.add_argument('--coverage-out', required=True)
    args = parser.parse_args()

    rewrite_with_header(args.strains, args.strains_out)
    rewrite_with_header(
        args.cov_stats,
        args.cov_stats_out,
        id_builder=build_covstats_id,
        skip_undetermined=True,
        row_formatter=format_covstats_row,
    )
    rewrite_with_header(
        args.cov_stats_filtered,
        args.cov_stats_filtered_out,
        id_builder=build_covstats_id,
        skip_undetermined=True,
        row_formatter=format_covstats_row,
    )
    rewrite_with_header(args.coverage, args.coverage_out)


if __name__ == '__main__':
    main()
