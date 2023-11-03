#!/usr/bin/env python3
#
# (c) Giorgio Gonnella (2023); License: CC-BY-SA
#
"""
Assign taxonomy IDs to taxonomy buckets.

For each taxonomy ID in the input file, find the lowest node among the
bucket heads that is an ancestor of the taxonomy ID.  If no bucket head
is an ancestor of the taxonomy ID, use the root ID.

If the first line does not contain an integer in the column, it is assumed to
be the header.

Output:
    TSV file with an additional column containing the bucket ID.

Usage:
  assign_to_buckets.py [options] <nodesdmp> <tsv_file> <column> <outfile> <bucket_heads>...

Arguments:
    <nodesdmp>         NCBI taxonomy dump nodes.dmp file.
    <tsv_file>         TSV file to process.
    <column>           Column containing taxonomy IDs (1-based).
    <outfile>          Output file.
    <bucket_heads>...  List of bucket heads (taxonomy IDs).

Options:
  --version     Show version.
  -h --help     Show this screen.
"""

from docopt import docopt
import csv
import loguru
import subprocess
import sys
from tqdm import tqdm
ROOT_ID = 1

def count_lines(file_path):
    result = subprocess.run(['wc', '-l', file_path],
                            stdout=subprocess.PIPE, text=True)
    line_count = result.stdout.split()[0]
    return int(line_count)

def load_taxonomy(nodesdmp):
    taxonomy_tree = {}
    with open(nodesdmp) as f:
        for line in tqdm(f, total=count_lines(nodesdmp)):
            fields = line.split('|')
            child_id = int(fields[0].strip())
            parent_id = int(fields[1].strip())
            taxonomy_tree[child_id] = parent_id
    return taxonomy_tree

def find_bucket(taxonomy_tree, start_id, bucket_heads):
    current_id = start_id
    while current_id != ROOT_ID:
        if current_id in bucket_heads:
            return current_id
        current_id = taxonomy_tree.get(current_id, ROOT_ID)
    return ROOT_ID

def process_tsv(tsv_file, column, out, bucket_heads, taxonomy_tree):
    with open(tsv_file) as infile, open(out, 'w') as outfile:
        reader = csv.reader(infile, delimiter='\t')
        writer = csv.writer(outfile, delimiter='\t')
        had_header = False
        counts = {ROOT_ID: 0}
        for bucket_head in bucket_heads:
            counts[bucket_head] = 0
        for row in tqdm(reader, total=count_lines(tsv_file)):
            if not had_header and not row[column - 1].isdigit():
                had_header = True
                writer.writerow(row + ['bucket'])
                continue
            tax_id = int(row[column - 1])
            bucket = find_bucket(taxonomy_tree, tax_id, bucket_heads)
            counts[bucket] += 1
            writer.writerow(row + [bucket])
        print('bucket\tcount')
        for bucket_head in bucket_heads:
            print(f'{bucket_head}\t{counts[bucket_head]}')


def main(args):
    loguru.logger.remove()
    loguru.logger.add(sys.stderr, level='INFO')
    nodesdmp = args['<nodesdmp>']
    tsv_file = args['<tsv_file>']
    out = args['<outfile>']
    column = int(args['<column>'])
    bucket_heads = set(map(int, args['<bucket_heads>']))
    loguru.logger.info(f'Loading taxonomy tree from file: {nodesdmp}')
    taxonomy_tree = load_taxonomy(nodesdmp)
    loguru.logger.info(f'Processing input TSV file: {tsv_file}')
    process_tsv(tsv_file, column, out, bucket_heads, taxonomy_tree)

if __name__ == '__main__':
    args = docopt(__doc__, version='0.1')
    main(args)
