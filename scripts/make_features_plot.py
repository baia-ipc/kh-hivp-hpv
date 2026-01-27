#!/usr/bin/env python3
"""
Visualizes features TSV file as rectangles along the x-axis (genomic position).

Usage:
  make_features_plot.py [options] <tsv_file> <output_file>

Arguments:
  <tsv_file>     Path to the input TSV file containing gene information.
                 (feature_name, start, end)
  <output_file>  Path to save the output plot (e.g., .png, .pdf).

Options:
  -h --help      Show this help message.
  -V --version   Show version.
  -v --verbose   Enable verbose output.
  -q --quiet     Suppress all output except errors.
"""

from docopt import docopt
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import pandas as pd
from loguru import logger
import seaborn as sns
from matplotlib.font_manager import FontProperties

def set_logger(verbose, quiet):
    logger.remove()
    if quiet:
        logger.add(lambda msg: None, level="DEBUG")
    elif verbose:
        logger.add(lambda msg: print(msg, end=''), level="INFO")
    else:
        logger.add(lambda msg: print(msg, end=''), level="WARNING")

def load_genes(tsv_file):
    logger.info(f"Loading gene data from {tsv_file}")
    df = pd.read_csv(tsv_file, sep='\t', names=['Gene', 'Start', 'End'])
    df['Start'] = df['Start'].astype(int)
    df['End'] = df['End'].astype(int)
    return df.sort_values(by='Start')

estimations = {}

def estimate_label_length(gene_name, font_size=10):
    if gene_name in estimations:
        return estimations[gene_name]
    font = FontProperties(family='sans-serif', size=font_size)
    res = plt.text(0, 0, gene_name, fontproperties=font).get_window_extent().width * 5
    logger.info(f"Estimated label length for gene {gene_name}: {res}")
    estimations[gene_name] = res
    return res

def gene_end(gene):
    # gene ['End'] position;
    # but if label is larger than gene length, then label end position
    # the label is centered on the gene position; so add half of it to the
    # half position of the gene
    label_length = estimate_label_length(gene['Gene'])
    label_end = gene['Start'] + (gene['End'] - gene['Start']) / 2 + label_length / 2
    logger.info(f"Gene {gene['Gene']} end position: {max(gene['End'], label_end)}")
    return max(gene['End'], label_end)

def gene_start(gene):
    # gene ['Start'] position;
    # but if label is larger than gene length, then label start position
    # the label is centered on the gene position; so subtract half of it to the
    # half position of the gene
    label_length = estimate_label_length(gene['Gene'])
    label_start = gene['Start'] + (gene['End'] - gene['Start']) / 2 - label_length / 2
    logger.info(f"Gene {gene['Gene']} start position: {min(gene['Start'], label_start)}")
    return min(gene['Start'], label_start)

def place_genes(df):
    logger.info("Placing genes on different lines to avoid overlap")
    lines = []
    buffer_space = 100

    for _, gene in df.iterrows():
        placed = False
        for line in lines:
            if all(
                # Check if the gene can be placed on the current line
                # by ensuring that it does not overlap with any other gene
                # on the line
                (gene_start(gene) > gene_end(g) + buffer_space or
                gene_end(g) + buffer_space < gene_start(g))
                for g in line
            ):
                line.append(gene)
                placed = True
                break

        if not placed:
            lines.append([gene])

    return lines

def plot_genes(df, strain, lines, output_file):
    logger.info(f"Plotting genes and saving to {output_file}")

    pastel_colors = sns.color_palette("pastel", len(df['Gene'].unique()))
    color_dict = {gene: pastel_colors[i] for i, gene in enumerate(df['Gene'].unique())}

    fig, ax = plt.subplots(figsize=(12, len(lines) * 2))

    for i, line in enumerate(lines):
        for gene in line:
            color = color_dict[gene['Gene']]
            rect = patches.Rectangle(
                (gene['Start'], i), gene['End'] - gene['Start'], 0.8,
                linewidth=1, edgecolor='black', facecolor=color
            )
            ax.add_patch(rect)
            ax.text(
                (gene['Start'] + gene['End']) / 2, i + 0.4, gene['Gene'],
                ha='center', va='center', fontsize=10, color='black'
            )

    ax.set_ylim(-0.25, len(lines))
    ax.set_xlim(0, df['End'].max() + 100)
    ax.set_xlabel('Genomic Position')
    ax.set_yticks([])
    ax.set_title('Strain')
    plt.tight_layout()
    plt.savefig(output_file)
    plt.close()

def main(tsv_file, output_file, verbose, quiet):
    set_logger(verbose, quiet)
    df = load_genes(tsv_file)
    strain = tsv_file.split('/')[-1].split('.')[0]
    if strain.endswith('REF'):
        strain = strain[:-3]
    lines = place_genes(df)
    plot_genes(df, strain, lines, output_file)

if __name__ == '__main__':
    arguments = docopt(__doc__, version='visualize_genes 1.4')
    main(
        tsv_file=arguments['<tsv_file>'],
        output_file=arguments['<output_file>'],
        verbose=arguments['--verbose'],
        quiet=arguments['--quiet']
    )
