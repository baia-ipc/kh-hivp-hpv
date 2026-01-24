#!/usr/bin/env python3

"""
Aggregate coverage statistics for all samples in a given directory tree.

Usage:
    aggregate_covstats.py [options] <input_dir> <output_file>

Arguments:
    <input_dir>       Root of the tree containing coverage statistics files
                      in files named: <input_dir>/<run_id>/<sample>.depth.stats.
    <output_file>     Output file for aggregated depth statistics.

Options:
    -d, --depth D     Mean coverage depth threshold [default: 5.0]
                      (mean depth value must be higher than this threshold)
    -b, --breadth B   Coverage breadth threshold [default: 0.50]
                      (breadth value must be higher than this threshold)
    -V, --version     Show version.
    -h, --help        Show this screen.

Input files have this structure

strain<tab>avg_cov_depth<tab>cov_breadth[<tab>...]
e.g.

HPV1REF 0.0     0.0
HPV6REF 0.0     0.0
HPV18REF        2.0582919689448897      0.7239404352806414
HPV2REF 0.0     0.0

after the avg_cov_depth and cov_breadth values there may be other values
which are the features average coverage depth and coverage breadth
named as "<FEATURE>_avg_cov_depth" and "<FEATURE>_cov_breadth"
the names can be obtained from the header of the file

this scripts collects the info for each strain for which the values
of mean coverage and coverage breadth are above the given thresholds

the output file has the following structure

run_id<tab>sample<tab>strain<tab>avg_cov_depth<tab>cov_breadth[<tab>...]

again, after the values for the genome, the features values may be added
if they are present in the input files

"""

from docopt import docopt
from pathlib import Path
import os
from collections import OrderedDict

def main(input_dir, output_file, depth_threshold, breadth_threshold):
    # first collect all output info, in order to know which features to write
    features = set()
    genome_results = OrderedDict()
    features_results = {}
    for run_id in os.listdir(input_dir):
        if not Path(input_dir).joinpath(run_id).is_dir():
            continue
        for file in os.listdir(Path(input_dir).joinpath(run_id)):
            if not file.endswith('.depth.stats'):
                continue
            with open(Path(input_dir).joinpath(run_id).joinpath(file), 'r') as f:
                sample = file.replace('.depth.stats', '')
                header = f.readline().strip().split('\t')
                features_order = []
                for h in header:
                    if h.endswith('_avg_cov_depth'):
                        featname = h.replace('_avg_cov_depth', '')
                        features.add(featname)
                        features_order.append(featname)
                for line in f:
                    elems = line.strip().split('\t')
                    strain = elems[0]
                    strain = strain.replace('REF', '')
                    avg_cov_depth = float(elems[1])
                    cov_breadth = float(elems[2])
                    if avg_cov_depth > depth_threshold:
                        key = "\t".join((run_id, sample, strain))
                        features_results[key] = {}
                        for i, featname in enumerate(features_order):
                            features_results[key][featname] = (elems[3 + (i * 2)], elems[4 + (i * 2)])
                        if cov_breadth > breadth_threshold or \
                                any(v[1] != "NA" and float(v[1]) > breadth_threshold for v in features_results[key].values()):
                            genome_results[key] = (avg_cov_depth, cov_breadth)
    # write the output file
    with open(output_file, 'w') as out:
        out.write('run_id\tsample\tstrain\tavg_cov_depth\tavg_cov_breadth')
        for featname in features:
            out.write(f'\t{featname}_avg_cov_depth\t{featname}_cov_breadth')
        out.write('\n')
        for key, (avg_cov_depth, cov_breadth) in genome_results.items():
            if avg_cov_depth > depth_threshold and cov_breadth > breadth_threshold:
                out.write(f'{key}\t{avg_cov_depth}\t{cov_breadth}')
                for featname in features:
                    f_avg_cov_depth, f_cov_breadth = features_results[key][featname]
                    out.write(f'\t{f_avg_cov_depth}\t{f_cov_breadth}')
                out.write('\n')


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
    args = docopt(__doc__, version='aggregate_covstats 1.1')
    main(*parse_args(args))
