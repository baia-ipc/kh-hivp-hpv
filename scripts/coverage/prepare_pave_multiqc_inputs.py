#!/usr/bin/env python
import argparse
import csv
import os


def rewrite_with_header(src, dest, use_strain=False):
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
            run = row[0] if len(row) > 0 else ''
            sid = row[1] if len(row) > 1 else ''
            strain = row[2] if len(row) > 2 else ''
            if use_strain:
                sample = f"{run}:{sid}:{strain}"
            else:
                sample = f"{run}:{sid}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare pave_gene_mapping tables for MultiQC.")
    parser.add_argument('--strains', required=True)
    parser.add_argument('--strains-out', required=True)
    parser.add_argument('--depth-unfiltered', required=True)
    parser.add_argument('--depth-unfiltered-out', required=True)
    parser.add_argument('--depth-filtered', required=True)
    parser.add_argument('--depth-filtered-out', required=True)
    args = parser.parse_args()

    rewrite_with_header(args.strains, args.strains_out)
    rewrite_with_header(args.depth_unfiltered, args.depth_unfiltered_out, use_strain=True)
    rewrite_with_header(args.depth_filtered, args.depth_filtered_out, use_strain=True)


if __name__ == '__main__':
    main()
