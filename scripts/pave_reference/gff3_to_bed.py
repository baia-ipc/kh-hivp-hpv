#!/usr/bin/env python3
"""
Parses a GFF3 file of a HPV strain from PaVE to extract gene and regulatory
regions information

Output: BED
  seq region, 0-based start position, 1-based end position, feature name

Splitted features are assigned a prefix -1, -2 ... for each of the
portions of the feature

Usage:
  gff3_to_bed.py [options] <gff3_file>

Arguments:
  <gff3_file>   Path to the input GFF3 file.

Options:
  -h --help     Show this help message.
  -V --version  Show version.
  -v --verbose  Enable verbose output.
  -q --quiet    Suppress all output except errors.
"""

from docopt import docopt
import csv
from loguru import logger
from collections import OrderedDict

def set_logger(verbose, quiet):
    logger.remove()
    if quiet:
        logger.add(lambda msg: None, level="DEBUG")
    elif verbose:
        logger.add(lambda msg: print(msg, end=''), level="INFO")
    else:
        logger.add(lambda msg: print(msg, end=''), level="WARNING")

def extract_gene_info(gff3_file):
    info = OrderedDict()
    with open(gff3_file, 'r') as f:
        for line in f:
            if line.startswith("#"):
                continue

            fields = line.strip().split("\t")
            if len(fields) < 9:
                continue

            seq_region = fields[0]
            seq_region = seq_region+"|lcl|Human"
            feature_type = fields[2]
            if feature_type == "gene" or feature_type == "regulatory_region":
                attributes = fields[8]
                attributes_dict = dict(item.split("=") for item in attributes.split(";") if "=" in item)

                gene_name = attributes_dict.get("Name", "Unknown")
                if gene_name == "Unknown":
                    continue
                if gene_name not in info:
                    info[gene_name] = []
                start = fields[3]
                end = fields[4]
                info[gene_name].append((start, end))
    out_info = OrderedDict()
    for gene_name, positions in info.items():
        if len(positions) > 1:
            for i, position in enumerate(positions):
                out_info[f"{gene_name}-{i+1}"] = positions[i]
        else:
            out_info[gene_name] = positions[0]
    out_info = OrderedDict(sorted(out_info.items(), key=lambda x: int(x[1][0])))
    for gene_name, (start, end) in out_info.items():
        start = int(start) - 1
        print(f"{seq_region}\t{start}\t{end}\t{gene_name}")

def main(gff3_file, verbose, quiet):
    set_logger(verbose, quiet)
    extract_gene_info(gff3_file)

if __name__ == '__main__':
    arguments = docopt(__doc__, version='1.0')
    main(
        gff3_file=arguments['<gff3_file>'],
        verbose=arguments['--verbose'],
        quiet=arguments['--quiet']
    )
