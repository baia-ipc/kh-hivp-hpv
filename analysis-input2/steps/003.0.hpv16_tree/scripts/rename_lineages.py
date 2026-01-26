#!/usr/bin/env python3
"""
Rename FASTA headers using metadata from a TSV file.

Usage: rename_fasta_prefix.py [options] <metadata_tsv> <accession> <prefix> <input_fasta> <output_fasta>

Arguments:
  <metadata_tsv>       TSV file with accession and metadata to add as prefix to the Fasta ID
  <accession>          1-based column number for accession
  <prefix>             1-based column number for metadata to add as prefix (e.g. lineage, country...)
  <input_fasta>        Input FASTA file with original headers
  <output_fasta>       Output FASTA file

Options:
  -v --verbose         Enable verbose logging
  -q --quiet           Suppress all logging output
  -h --help            Show this help message and exit
  -V --version         Show version and exit
"""

import sys
import re
from docopt import docopt
from loguru import logger
from Bio import SeqIO

def set_logger(verbose, quiet):
    logger.remove()
    if quiet:
        logger.add(lambda msg: None, level="DEBUG")
    elif verbose:
        logger.add(lambda msg: sys.stderr.write(msg), level="INFO")
    else:
        logger.add(lambda msg: sys.stderr.write(msg), level="WARNING")

def parse_metadata_tsv(metadata_file, acc_col, prefix_col):
    metadata = {}
    with open(metadata_file, 'r') as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < max(acc_col, prefix_col):
                logger.warning(f"Skipping line {lineno}: not enough columns.")
                continue
            acc = parts[acc_col - 1].split('.')[0]  # Strip version
            prefix = parts[prefix_col - 1]
            metadata[acc] = prefix
    logger.info(f"Loaded {len(metadata)} metadata records.")
    return metadata

def rename_fasta_headers(metadata_file, input_fasta, output_file, acc_col, prefix_col):
    metadata = parse_metadata_tsv(metadata_file, acc_col, prefix_col)
    count = 0
    with open(output_file, 'w') as out_f:
        for record in SeqIO.parse(input_fasta, "fasta"):
            acc_match = re.match(r'(\S+?)(\.\d+)?$', record.id)
            if acc_match:
                acc_unversioned = acc_match.group(1)
                if acc_unversioned in metadata:
                    new_id = f"{metadata[acc_unversioned]}/{record.id}"
                    logger.info(f"Renaming {record.id} -> {new_id}")
                    record.id = new_id
                    record.description = ""
                else:
                    logger.warning(f"No metadata found for {record.id}, keeping original.")
            else:
                logger.warning(f"Unrecognized ID format: {record.id}, keeping original.")
            SeqIO.write(record, out_f, "fasta")
            count += 1
    logger.info(f"Processed {count} FASTA records.")

if __name__ == '__main__':
    args = docopt(__doc__, version='rename_fasta_prefix 1.1')
    set_logger(args['--verbose'], args['--quiet'])
    rename_fasta_headers(
        metadata_file=args['<metadata_tsv>'],
        input_fasta=args['<input_fasta>'],
        output_file=args['<output_fasta>'],
        acc_col=int(args['<accession>']),
        prefix_col=int(args['<prefix>'])
    )
