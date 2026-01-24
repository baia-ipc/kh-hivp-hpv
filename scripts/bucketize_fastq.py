#!/usr/bin/env python3
"""
Divide a FASTQ file into multiple files based on a TSV file
containing read IDs and bucket IDs.

Usage:
  bucketize_fastq.py [options] <tsv_file> <read_id_col> <bucket_id_col> <fastq_file> <bucket_basename>

Options:
  --version     Show version.
  --skip ID     Skip reads with this bucket ID or a comma-separated list of IDs.
  -h --help     Show this screen.
"""

from docopt import docopt
import csv
import gzip
import loguru
import subprocess
import sys
from tqdm import tqdm

def count_lines(file_path):
    result = subprocess.run(['wc', '-l', file_path],
                            stdout=subprocess.PIPE, text=True)
    line_count = result.stdout.split()[0]
    return int(line_count)

def count_gzipped_lines(file_path):
    cmd = f'zcat {file_path} | wc -l'
    result = subprocess.run(cmd, shell=True,
                            stdout=subprocess.PIPE, text=True)
    line_count = result.stdout.strip()
    return int(line_count)

def read_bucket_assignments(tsv_file, read_id_col, bucket_id_col):
    bucket_dict = {}
    with open(tsv_file) as f:
        reader = csv.reader(f, delimiter='\t')
        for row in tqdm(reader, total=count_lines(tsv_file)):
            read_id = row[read_id_col - 1]
            bucket_id = row[bucket_id_col - 1]
            bucket_dict[read_id] = bucket_id
    return bucket_dict

def process_fastq(fastq_file, bucket_dict, bucket_basename, skip):
    bucket_files = {}
    counts = {}
    with gzip.open(fastq_file, 'rt') as infile:
        with tqdm(total=count_gzipped_lines(fastq_file)) as pbar:
            while True:
                identifier = infile.readline().strip()
                if not identifier:
                    break  # End of file
                sequence = infile.readline().strip()
                plus_line = infile.readline().strip()
                quality_scores = infile.readline().strip()
                read_id = identifier.split()[0][1:]
                bucket_id = bucket_dict.get(read_id)
                if bucket_id is None:
                    print(f'Warning: Read ID {read_id} not found in bucket dict.'+
                          "It will be assigned to a bucket '0'.", file=sys.stderr)
                    bucket_id = 0
                if bucket_id not in skip:
                    if bucket_id not in bucket_files:
                        bucket_files[bucket_id] = gzip.open(
                              f'{bucket_basename}.{bucket_id}.fastq.gz', 'wt')
                    bucket_file = bucket_files[bucket_id]
                    bucket_file.write(f'{identifier}\n{sequence}\n'+
                                      f'{plus_line}\n{quality_scores}\n')
                counts[bucket_id] = counts.get(bucket_id, 0) + 1
                pbar.update(4)

    for bucket_file in bucket_files.values():
        bucket_file.close()
    print('bucket_id\tcount')
    for bucket_id, count in counts.items():
        print(f'{bucket_id}\t{count}')

def main(args):
    loguru.logger.remove()
    loguru.logger.add(sys.stderr, level='INFO')
    tsv_file = args['<tsv_file>']
    read_id_col = int(args['<read_id_col>'])
    bucket_id_col = int(args['<bucket_id_col>'])
    fastq_file = args['<fastq_file>']
    bucket_basename = args['<bucket_basename>']
    skip = args['--skip']
    if skip:
        skip = skip.split(',')
        loguru.logger.info(f'Skipping reads with bucket IDs: {skip}')
    else:
        skip = []

    loguru.logger.info(f'Reading bucket assignments from file: {tsv_file}')
    bucket_dict = read_bucket_assignments(tsv_file, read_id_col, bucket_id_col)
    loguru.logger.info(f'Processing FASTQ file: {fastq_file}')
    process_fastq(fastq_file, bucket_dict, bucket_basename, skip)

if __name__ == '__main__':
    args = docopt(__doc__, version='0.1')
    main(args)
