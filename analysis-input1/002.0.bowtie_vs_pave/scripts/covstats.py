#!/usr/bin/env python3

"""
Compute coverage statistics from the 'samtools depth -aa' output

The script computes:
    - average depth of coverage
    - breadth of coverage

Usage: covstats.py [options] <depth_file> <output_file> [<tsvfiles>]

Arguments:
    depth_file      samtools depth -a output file
    output_file     output file
    tsvfiles        features tsv files directory (optional)
                    Format: FeatureName\tStart\tEnd

If specified, in the tsvfiles directory, the filenames must
be <strain>REF.tsv, where <strain>REF is the first column in
the depth_file, before the first '|'.

Options:
    -h --help       show this help message and exit
    --version       show version and exit
    --features F    list of features to compute coverage for [default: E6,E7]
                    (this is only used if tsvfiles is specified)
"""

import docopt
import sys

def main(depth_file, output_file, tsvfiles, features):
    depth = {}
    with open(depth_file, 'r') as f:
        for line in f:
            strain = line.split()[0].split('|')[0]
            if strain not in depth:
                depth[strain] = []
            depth[strain].append(int(line.strip().split()[2]))

    outfile = open(output_file, 'w')
    outfile.write('#strain\tavg_cov_depth\tcov_breadth')
    if tsvfiles:
        for feature in features:
            outfile.write(f'\t{feature}_avg_cov_depth\t{feature}_cov_breadth')
    outfile.write('\n')
    for strain in depth:
        avg_depth = sum(depth[strain]) / len(depth[strain])
        breadth = len([d for d in depth[strain] if d > 0]) / len(depth[strain])
        if tsvfiles:
            feature_results = {}
            with open(f'{tsvfiles}/{strain}.tsv', 'r') as f:
                for line in f:
                    feature, start, end = line.split()
                    if feature not in features:
                        continue
                    start = int(start)
                    end = int(end)
                    feature_depth = [d for i, d in enumerate(depth[strain]) if i >= start and i <= end]
                    feature_avg_depth = sum(feature_depth) / len(feature_depth)
                    feature_breadth = len([d for d in feature_depth if d > 0]) / len(feature_depth)
                    feature_results[feature] = (feature_avg_depth, feature_breadth)
            outfile.write(f'{strain}\t{avg_depth}\t{breadth}')
            for feature in features:
                if feature in feature_results:
                    f_avg_depth = feature_results[feature][0]
                    f_breadth = feature_results[feature][1]
                    outfile.write(f'\t{f_avg_depth}\t{f_breadth}')
                else:
                    outfile.write('\tNA\tNA')
            outfile.write('\n')
        else:
            outfile.write(f'{strain}\t{avg_depth}\t{breadth}\n')

if __name__ == '__main__':
    args = docopt.docopt(__doc__, version='0.1')
    main(args['<depth_file>'], args['<output_file>'],
         args['<tsvfiles>'], args['--features'].split(','))

