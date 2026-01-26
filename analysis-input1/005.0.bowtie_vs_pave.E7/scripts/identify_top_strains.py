#!/usr/bin/env python3
"""
Parse the output of samtools idxstats and identify the top strains.

Usage: identify_top_strains.py [options] <idxstats_output.txt>

Options:
    -h, --help          Show this help message and exit
    --version           Show version and exit
    -t, --threshold T   Minimum count ratio between a strain s in the list of
                        strains sorted by count (high to low) to be considered
                        "top". If s0 is the strain with the highest count, then
                        s is a top strain if count(s) >= t * count(s0).
                        [Default: 0.2]
    -m, --mincount N    Minimum count for a strain to be "top" [Default: 10]
"""

import sys
import docopt
import loguru

def parse_idxstats(filename):
    strains = {}  # Dictionary to hold strain name and read count
    with open(filename, 'r') as f:
        for line in f:
            fields = line.strip().split('\t')
            strain_name = fields[0].split('|')[0]
            # strip REF at the end of strain name
            if strain_name.endswith('REF'):
                strain_name = strain_name[:-3]
            read_count = int(fields[2])
            if read_count > 0:
                strains[strain_name] = read_count
    return strains

def identify_top_strains(strains, threshold_ratio, mincount):
    sorted_strains = sorted(strains.items(), key=lambda x: x[1], reverse=True)
    k_strains = {"t": [], "nt": []}
    if len(sorted_strains) > 0:
      topcount = float(sorted_strains[0][1])
      if topcount >= mincount:
          k_strains["t"] = [sorted_strains[0]]
          non_top = False
      else:
          k_strains["nt"] = [sorted_strains[0]]
          non_top = True
      for i in range(1, len(sorted_strains)):
          if not non_top and sorted_strains[i][1] >= mincount:
              if sorted_strains[i][1] / topcount >= threshold_ratio:
                  k_strains["t"].append(sorted_strains[i])
                  continue
          non_top = True
          k_strains["nt"].append(sorted_strains[i])
    return k_strains

def print_output(filename, k_strains):
    header = ["sample", "n_top_strains", "top_strains", "top_strains_counts",
              "n_other_strains", "nontop_strains", "nontop_strains_counts"]
    print("\t".join(header))
    sample = filename.split('/')[-1].split('.')[0]
    output = [sample]
    for strain_type in ["t", "nt"]:
        output.append(len(k_strains[strain_type]))
        if len(k_strains[strain_type]) == 0:
            output.append("NA")
            output.append("0")
        elif len(k_strains[strain_type]) == 1:
            output.append(k_strains[strain_type][0][0])
            output.append(k_strains[strain_type][0][1])
        elif len(k_strains[strain_type]) > 1:
            output.append(",".join([s[0] for s in k_strains[strain_type]]))
            output.append(",".join([str(s[1]) for s in k_strains[strain_type]]))
    print("\t".join([str(x) for x in output]))
    loguru.logger.info(f"Output: {output}")

def main(filename, threshold_ratio, mincount):
    loguru.logger.info(f"Processing {filename}")
    strains = parse_idxstats(filename)
    k_strains = identify_top_strains(strains, threshold_ratio, mincount)
    print_output(filename, k_strains)

if __name__ == "__main__":
    args = docopt.docopt(__doc__, version="1.0")
    filename = args['<idxstats_output.txt>']
    threshold_ratio = float(args['--threshold'])
    mincount = int(args['--mincount'])
    main(filename, threshold_ratio, mincount)
