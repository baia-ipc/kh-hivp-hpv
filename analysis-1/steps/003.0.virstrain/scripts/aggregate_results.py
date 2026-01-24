#!/usr/bin/env python3
"""
Aggregate virstrain results from all runs and sample IDs.

Usage:
    aggregate_results.py [options] <results_dir>

Options:
    -h --help                   Show this screen.
    --version                   Show version.
    --maxstrains N              Maximum number of strains to report [default: 5]
"""

import docopt
import os
import glob
import re
import csv

def parse_report(file_path, maxstrains):
    with open(file_path, 'r') as file:
        data = file.readlines()
    for i, line in enumerate(data):
        if line.startswith(">>Most possible strains:"):
            data = data[i+1:]
            break
    for i, line in enumerate(data):
        if line.startswith(">>Other possible strains:"):
            data = data[:i]
            break
    strains = []
    for line in data:
        elements = line.split("\t")
        strain_name = elements[2].split(">")[1]
        if strain_name.endswith("REF"):
            strain_name = strain_name[:-3]
        strains.append(strain_name)
    if len(strains) > maxstrains:
        return f"Too many possible strains ({len(strains)})"
    else:
        return ",".join(strains)

def main(results_dir, maxstrains):
    output_dirs = glob.glob(os.path.join(results_dir, '*', '*'))
    for output_dir in output_dirs:
        run_id = output_dir.split("/")[-2]
        sample_id = output_dir.split("/")[-1]
        report_file = os.path.join(output_dir, "VirStrain_report.txt")
        if os.path.exists(report_file):
            data = [run_id, sample_id, parse_report(report_file, maxstrains)]
        else:
            data = [run_id, sample_id, "No reads or too few reads"]
        print("\t".join(data))

if __name__ == '__main__':
    args = docopt.docopt(__doc__, version='0.1')
    results_dir = args['<results_dir>']
    maxstrains = int(args['--maxstrains'])
    main(results_dir, maxstrains)
