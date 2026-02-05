#!/usr/bin/env python
import argparse
import csv
import os


def main():
    parser = argparse.ArgumentParser(
        description="Prepare virstrain tables for MultiQC.")
    parser.add_argument('--strains', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()

    header = ['run', 'sample', 'strains']

    if not os.path.exists(args.strains):
        return

    with open(args.strains, newline='') as inp, open(args.out, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        first = next(reader, None)
        if not first:
            return
        if len(first) != len(header):
            header = header + [f"col{i}" for i in range(len(header) + 1, len(first) + 1)]
        writer.writerow(['Sample'] + header[:len(first)])
        sample = f"{first[0]}:{first[1]}" if len(first) > 1 else first[0]
        writer.writerow([sample] + first)
        for row in reader:
            if not row:
                continue
            sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)


if __name__ == '__main__':
    main()
