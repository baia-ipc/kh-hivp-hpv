#!/usr/bin/env python3
"""
Aggregate bucket size information for all runs and samples.

Usage:
  aggregate_bucket_counts.py [options] <bucket_ids_table> <root> <outputdir>

Arguments:
    <bucket_ids_table>  Path to the tsv file mapping bucket IDs to bucket names.
    <root>              Path to the root directory containing the output for all runs.
    <outputdir>         Path to the output directory.

Options:
  --version       Show version.
  --no-rel        Do not output relative counts.
  --no-abs        Do not output absolute counts.
  --abs-fname FN  Name for the absolute counts table [default: absolute_counts.tsv].
  --rel-fname FN  Name for the relative counts table [default: relative_counts.tsv].
  --skip ID       Skip bucket with the given ID (or ID list, comma-sep).
  -h --help       Show this screen.
"""

from docopt import docopt
from collections import OrderedDict
import csv
import os

def load_bucket_names(bucket_ids_table):
    bucket_names = OrderedDict()
    with open(bucket_ids_table) as file:
        reader = csv.reader(file, delimiter='\t')
        for row in reader:
            bucket_names[row[0]] = row[1]
    return bucket_names

def get_header(bucket_names):
    return ['Run ID', 'Sample ID'] + \
                [f'{name} ({id})' for id, name in bucket_names.items()]

def write_absolute_counts(outputdir, bucket_names, aggregate_data, filename):
    with open(os.path.join(outputdir, filename), 'w') as f:
        writer = csv.writer(f, delimiter='\t')
        writer.writerow(get_header(bucket_names))
        for (run_id, sample_id), (total_count, bucket_counts) in \
                aggregate_data.items():
            row = [run_id, sample_id] + \
                    [bucket_counts.get(id, 0) for id in bucket_names.keys()]
            writer.writerow(row)

def write_relative_counts(outputdir, bucket_names, aggregate_data, filename):
    with open(os.path.join(outputdir, filename), 'w') as f:
        writer = csv.writer(f, delimiter='\t')
        writer.writerow(get_header(bucket_names))
        for (run_id, sample_id), (total_count, bucket_counts) in \
                aggregate_data.items():
            row = [run_id, sample_id] + \
                    [bucket_counts.get(id, 0) / \
                     total_count for id in bucket_names.keys()]
            writer.writerow(row)

def process_bucket_sizes(bucket_names, root, outputdir, no_rel, no_abs, skip,
                         abs_fname, rel_fname):
    aggregate_data = {}
    for run_id in os.listdir(root):
        run_dir = os.path.join(root, run_id, 'bucket_sizes')
        if os.path.isdir(run_dir):
            for sample_file in os.listdir(run_dir):
                sample_id = sample_file.split('.')[0]
                file_path = os.path.join(run_dir, sample_file)
                with open(file_path) as file:
                    reader = csv.reader(file, delimiter='\t')
                    total_count = 0
                    bucket_counts = {}
                    for row in reader:
                        if not row[0].isdigit():
                            continue
                        if row[0] in skip:
                            continue
                        bucket_id = row[0]
                        count = int(row[1])
                        total_count += count
                        bucket_counts[bucket_id] = count
                    aggregate_data[(run_id, sample_id)] = \
                      (total_count, bucket_counts)
    os.makedirs(outputdir, exist_ok=True)
    if not no_abs:
        write_absolute_counts(outputdir, bucket_names,
                              aggregate_data, abs_fname)
    if not no_rel:
        write_relative_counts(outputdir, bucket_names,
                              aggregate_data, rel_fname)

def main(args):
    bucket_ids_table = args['<bucket_ids_table>']
    bucket_names = load_bucket_names(bucket_ids_table)
    skip = args['--skip']
    if skip is not None:
        skip = skip.split(',')
    else:
        skip = []
    if skip:
        for id in skip:
            bucket_names.pop(id, None)
    process_bucket_sizes(bucket_names, args['<root>'], args["<outputdir>"],
                         args["--no-rel"], args["--no-abs"], skip,
                         args["--abs-fname"], args["--rel-fname"])

if __name__ == '__main__':
    args = docopt(__doc__, version='1.0')
    main(args)

