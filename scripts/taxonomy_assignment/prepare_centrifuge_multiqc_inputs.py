#!/usr/bin/env python
import argparse
import csv


def rewrite(src, dest):
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        header = next(reader, None)
        if header:
            writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            sample = f"{row[0]}:{row[1]}"
            writer.writerow([sample] + row)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare centrifuge bucketing tables for MultiQC.")
    parser.add_argument('--absolute', required=True)
    parser.add_argument('--absolute-out', required=True)
    parser.add_argument('--relative', required=True)
    parser.add_argument('--relative-out', required=True)
    parser.add_argument('--relative-wo-human', required=True)
    parser.add_argument('--relative-wo-human-out', required=True)
    args = parser.parse_args()

    rewrite(args.absolute, args.absolute_out)
    rewrite(args.relative, args.relative_out)
    rewrite(args.relative_wo_human, args.relative_wo_human_out)


if __name__ == '__main__':
    main()
