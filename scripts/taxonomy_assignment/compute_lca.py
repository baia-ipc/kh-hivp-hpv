#!/usr/bin/env python3
"""
Compute for each read pair in the tabular output of centrifuge,
the lowest common ancestor (LCA) of all its taxonomic assignments

Usage:
  compute_lca.py [options] <nodesdmp> <centrifuge_tsv> <outfile>

Arguments:
    <nodesdmp>        Path to nodes.dmp file from NCBI taxonomy dump
    <centrifuge_tsv>  Path to tabular output of centrifuge
    <outfile>         Path to output file

Output:
  tabular file with read id and LCA taxonomic assignment

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

def get_ancestors(taxonomy_tree, tax_id):
    ancestors = [tax_id]
    while tax_id != 1:
        tax_id = taxonomy_tree.get(tax_id, ROOT_ID)
        ancestors.append(tax_id)
    return ancestors

def find_lca(taxonomy_tree, tax_ids):
    ancestors = [get_ancestors(taxonomy_tree, tax_id) for tax_id in tax_ids]
    for node in ancestors[0]:
        if all(node in ancestor for ancestor in ancestors[1:]):
            return node
    assert False, 'No LCA found'

def output_lca(taxonomy_tree, tax_ids, expected_n_matches, outfile, read_id):
    if expected_n_matches != len(tax_ids):
        raise ValueError(
                'Expected number of matches (' +
                str(expected_n_matches) +
                ') does not match number of matches (' +
                str(len(tax_ids)) +
                ') found for read "' + read_id + '"')
    if len(tax_ids) > 1:
        lca = find_lca(taxonomy_tree, tax_ids)
    else:
        lca = tax_ids[0]
    outfile.write(f'{read_id}\t{lca}\n')

def process_centrifuge_tsv(centrifuge_tsv, taxonomy_tree, out):
    with open(centrifuge_tsv) as infile, open(out, 'w') as outfile:
        reader = csv.reader(infile, delimiter='\t')
        prev_read_id = None
        tax_ids = []
        expected_n_matches = 0
        for row in tqdm(reader, total=count_lines(centrifuge_tsv)):
            if not row[2].isdigit():
                continue
            read_id, tax_id, n_matches = row[0], int(row[2]), int(row[7])
            if prev_read_id is None:
                prev_read_id = read_id
                tax_ids = [tax_id]
                expected_n_matches = n_matches
            elif read_id != prev_read_id:
                output_lca(taxonomy_tree, tax_ids,
                           expected_n_matches, outfile, prev_read_id)
                tax_ids = [tax_id]
                prev_read_id = read_id
                expected_n_matches = n_matches
            else:
                if expected_n_matches != n_matches:
                    raise ValueError(
                            'Number of matches column values do not match '
                            'for read "' + read_id + '": values found: ' +
                            str(n_matches) + ' and ' + str(expected_n_matches))
                tax_ids.append(tax_id)
        output_lca(taxonomy_tree, tax_ids, expected_n_matches,
                   outfile, prev_read_id)

def main(args):
    loguru.logger.remove()
    loguru.logger.add(sys.stderr, level='INFO')
    nodesdmp = args['<nodesdmp>']
    centrifuge_tsv = args['<centrifuge_tsv>']
    out = args['<outfile>']
    loguru.logger.info(f'Loading taxonomy tree from file: {nodesdmp}')
    taxonomy_tree = load_taxonomy(nodesdmp)
    loguru.logger.info(f'Processing input TSV file: {centrifuge_tsv}')
    process_centrifuge_tsv(centrifuge_tsv, taxonomy_tree, out)

if __name__ == '__main__':
    args = docopt(__doc__, version='0.1')
    main(args)

