#!/usr/bin/env python3

"""
Compute depth statistics from the 'samtools depth -aa' output

The script computes:
    - average depth of coverage
    - breadth of coverage

Usage: depth_stats.py [options] <depth_file> <output_file>

Arguments:
    depth_file      samtools depth -a output file
    output_file     output file

Options:
    -h --help       show this help message and exit
    --version       show version and exit
"""

import docopt
import sys

def main(depth_file, output_file):
    depth = {}
    with open(depth_file, 'r') as f:
        for line in f:
            strain = line.split()[0].split('|')[0]
            if strain not in depth:
                depth[strain] = []
            depth[strain].append(int(line.strip().split()[2]))

    outfile = open(output_file, 'w')
    for strain in depth:
        avg_depth = sum(depth[strain]) / len(depth[strain])
        breadth = len([d for d in depth[strain] if d > 0]) / len(depth[strain])
        outfile.write(f'{strain}\t{avg_depth}\t{breadth}\n')

if __name__ == '__main__':
    args = docopt.docopt(__doc__, version='0.1')
    main(args['<depth_file>'], args['<output_file>'])

