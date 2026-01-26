#!/usr/bin/env python3

"""
Aggregate depth statistics for all samples in a given directory tree.

Usage:
    aggregate_depth_stats.py [options] <input_dir> <output_file>

Arguments:
    <input_dir>       Root of the tree containing depth statistics files.
                      The sample depth statistics files are expected to be
                      in files named: <input_dir>/<run_id>/<sample>.depth.stats.
    <output_file>     Output file for aggregated depth statistics.

Options:
    -d, --depth D     Mean coverage depth threshold [default: 1.0]
                      (mean depth value must be higher than this threshold)
    -b, --breadth B   Coverage breadth threshold [default: 0.01]
                      (breadth value must be higher than this threshold)
    -V, --version     Show version.
    -h, --help        Show this screen.
"""

from docopt import docopt
from pathlib import Path
import os

#
# Input files have this structure
#
# strain<tab>mean_coverage_depth<tab>coverage_breadth
# e.g.
#
# HPV1REF 0.0     0.0
# HPV6REF 0.0     0.0
# HPV18REF        2.0582919689448897      0.7239404352806414
# HPV2REF 0.0     0.0
#
# this scripts collects the info for each strain for which the values
# of mean coverage and coverage breadth are above the given thresholds
#
# the output file has the following structure
#
# run_id<tab>sample<tab>strain<tab>mean_coverage_depth<tab>coverage_breadth
#
# the files are called <input_dir>/<run_id>/<sample>.depth.stats
#

def main(input_dir, output_file, depth_threshold, breadth_threshold):
    with open(output_file, 'w') as out:
        out.write('run_id\tsample\tstrain\tmean_coverage_depth\tcoverage_breadth\n')
        for run_id in os.listdir(input_dir):
            if not Path(input_dir).joinpath(run_id).is_dir():
                continue
            for file in os.listdir(Path(input_dir).joinpath(run_id)):
                if not file.endswith('.depth.stats'):
                    continue
                with open(Path(input_dir).joinpath(run_id).joinpath(file), 'r') as f:
                    sample = file.replace('.depth.stats', '')
                    for line in f:
                        strain, mean_depth, breadth = line.strip().split('\t')
                        # remove "REF" from the strain name
                        strain = strain.replace('REF', '')
                        if float(mean_depth) > depth_threshold and float(breadth) > breadth_threshold:
                            out.write(f'{run_id}\t{sample}\t{strain}\t{mean_depth}\t{breadth}\n')

def parse_args(args):
    input_dir = args['<input_dir>']
    if not Path(input_dir).is_dir():
        raise ValueError(f'Invalid input directory: {input_dir}')
    if not any(Path(input_dir).joinpath(run_id).is_dir() for run_id in os.listdir(input_dir)):
        raise ValueError(f'Input directory does not contain any run subdirectories: {input_dir}')
    if not any(Path(input_dir).joinpath(run_id).joinpath(sample).is_file() and \
            Path(input_dir).joinpath(run_id).joinpath(sample).name.endswith('.depth.stats') \
            for run_id in os.listdir(input_dir) \
            for sample in os.listdir(Path(input_dir).joinpath(run_id))):
        raise ValueError(f'Input directory does not contain any depth statistics files: {input_dir}')
    output_file = args['<output_file>']
    outdir = os.path.dirname(output_file)
    if outdir and not os.path.isdir(outdir):
        os.makedirs(outdir)
    depth_threshold = float(args['--depth'])
    if depth_threshold < 0:
        raise ValueError('Depth threshold must be greater than or equal to 0')
    breadth_threshold = float(args['--breadth'])
    if breadth_threshold < 0:
        raise ValueError('Breadth threshold must be greater than or equal to 0')
    return input_dir, output_file, depth_threshold, breadth_threshold

if __name__ == '__main__':
    args = docopt(__doc__, version='aggregate_depth_stats 1.0')
    main(*parse_args(args))
