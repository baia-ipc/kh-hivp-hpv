#!/usr/bin/env python3
"""
Keep only the string before the first | or , in Multifasta description lines
to make it compatible with virstrain_build.

Usage:
  ./fix_msa_formatting.py [options] <msa>

Arguments:
  <msa>   Input Fasta file

Options:
  -h, --help   Show this help message and exit
  --version    Show version and exit
"""
import docopt

def main(msa):
    with open(msa, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                print(line.split('|')[0].split(',')[0])
            else:
                print(line)

if __name__ == '__main__':
    args = docopt.docopt(__doc__, version='0.1')
    main(args['<msa>'])
