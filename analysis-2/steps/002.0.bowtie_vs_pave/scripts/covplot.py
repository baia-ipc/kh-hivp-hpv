#!/usr/bin/env python3
"""
Visualizes features from a TSV file as rectangles below the x-axis and adds a coverage plot from a .depth file above the x-axis.
Additionally, computes and displays mean coverage and coverage breadth for the entire genome and specific genes (E6, E7).

Usage:
  covplot.py [options] <depth_file> <strain_name> <tsv_file> <output_file>

Arguments:
  <depth_file>   Path to the .depth file containing coverage information.
                 Format: output format of samtools depth -aa
  <strain_name>  Name of the strain to match in the depth file.
                 (Part before the first '|' in the strain column)
  <tsv_file>     Path to the input TSV file containing features information.
                 Format: feature_name <tab> start_position <tab> end_position
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
from matplotlib.gridspec import GridSpec

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

def load_coverage(depth_file, strain_name):
    logger.info(f"Loading coverage data from {depth_file} for strain {strain_name}")
    df = pd.read_csv(depth_file, sep='\t', names=['Strain', 'Position', 'Coverage'])
    df['Strain'] = df['Strain'].apply(lambda x: x.split('|')[0])
    df = df[df['Strain'] == strain_name]
    df['Position'] = df['Position'].astype(int)
    df['Coverage'] = df['Coverage'].astype(int)
    if df.empty:
        logger.warning(f"No coverage data found for strain {strain_name}")
    return df

def calculate_coverage_metrics(coverage_df, start=None, end=None):
    if start and end:
        coverage_region = coverage_df[(coverage_df['Position'] >= start) & (coverage_df['Position'] <= end)]
    else:
        coverage_region = coverage_df

    if coverage_region.empty:
        return 0, 0

    total_depth = coverage_region['Coverage'].sum()
    avg_depth = total_depth / len(coverage_region)
    breadth = len(coverage_region[coverage_region['Coverage'] > 0]) / len(coverage_region)

    return avg_depth, breadth

def annotate_metrics(ax, coverage_df, genes_df):
    genome_avg_depth, genome_breadth = calculate_coverage_metrics(coverage_df)

    e6 = genes_df[genes_df['Gene'] == 'E6'].iloc[0]
    e6_avg_depth, e6_breadth = calculate_coverage_metrics(coverage_df, e6['Start'], e6['End'])

    e7 = genes_df[genes_df['Gene'] == 'E7'].iloc[0]
    e7_avg_depth, e7_breadth = calculate_coverage_metrics(coverage_df, e7['Start'], e7['End'])

    textstr1 = '\n'.join((
        f'Mean cov.',
        f'Cov. breadth'
    ))

    textstr2 = '\n'.join((
        f'genome: {genome_avg_depth:.2f}',
        f'genome: {genome_breadth:.2%}'
    ))

    textstr3 = '\n'.join((
        f'E6: {e6_avg_depth:.2f}',
        f'E6: {e6_breadth:.2%}'
    ))

    textstr4 = '\n'.join((
        f'E7: {e7_avg_depth:.2f}',
        f'E7: {e7_breadth:.2%}'
    ))

    ax.text(0.02, 0.98, textstr1, transform=ax.transAxes, fontsize=8, verticalalignment='top')
    ax.text(0.10, 0.98, textstr2, transform=ax.transAxes, fontsize=8, verticalalignment='top')
    ax.text(0.20, 0.98, textstr3, transform=ax.transAxes, fontsize=8, verticalalignment='top')
    ax.text(0.28, 0.98, textstr4, transform=ax.transAxes, fontsize=8, verticalalignment='top')

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
    label_length = estimate_label_length(gene['Gene'])
    label_end = gene['Start'] + (gene['End'] - gene['Start']) / 2 + label_length / 2
    logger.info(f"Gene {gene['Gene']} end position: {max(gene['End'], label_end)}")
    return max(gene['End'], label_end)

def gene_start(gene):
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

def plot_genes_and_coverage(df, coverage_df, lines, output_file):
    logger.info(f"Plotting genes and coverage and saving to {output_file}")

    fig = plt.figure(figsize=(12, 8))
    gs = GridSpec(2, 1, height_ratios=[3, 1])

    # Coverage Plot
    ax_coverage = fig.add_subplot(gs[0])
    ax_coverage.plot(coverage_df['Position'], coverage_df['Coverage'], color='gray', alpha=0.5, label='Coverage')
    ax_coverage.set_ylabel('Coverage')
    ax_coverage.set_xlim(0, df['End'].max() + 100)
    ax_coverage.grid(False)
    ax_coverage.set_ylim(0, coverage_df['Coverage'].max() * 1.1)

    annotate_metrics(ax_coverage, coverage_df, df)

    # Gene Plot (Below X-axis)
    ax_genes = fig.add_subplot(gs[1], sharex=ax_coverage)
    ax_genes.set_ylim(-len(lines), 0)
    ax_genes.set_xlim(0, df['End'].max() + 100)
    ax_genes.set_xlabel('Genomic Position')
    ax_genes.set_yticks([])
    #ax_genes.set_xticks([])  # Problem: if I hide x-axis ticks for the genes
                              # the coverage plot x-axis ticks are also hidden

    pastel_colors = sns.color_palette("pastel", len(df['Gene'].unique()))
    color_dict = {gene: pastel_colors[i] for i, gene in enumerate(df['Gene'].unique())}

    for i, line in enumerate(lines):
        for gene in line:
            color = color_dict[gene['Gene']]
            rect = patches.Rectangle(
                (gene['Start'], -i - 1), gene['End'] - gene['Start'], 0.8,
                linewidth=1, edgecolor='black', facecolor=color
            )
            ax_genes.add_patch(rect)
            ax_genes.text(
                (gene['Start'] + gene['End']) / 2, -i - 1 + 0.4, gene['Gene'],
                ha='center', va='center', fontsize=10, color='black'
            )

    plt.tight_layout()
    plt.savefig(output_file)
    plt.close()

def main(tsv_file, output_file, strain_name, depth_file, verbose, quiet):
    set_logger(verbose, quiet)
    df = load_genes(tsv_file)
    coverage_df = load_coverage(depth_file, strain_name)
    lines = place_genes(df)
    plot_genes_and_coverage(df, coverage_df, lines, output_file)

if __name__ == '__main__':
    arguments = docopt(__doc__, version='1.3')
    main(
        tsv_file=arguments['<tsv_file>'],
        output_file=arguments['<output_file>'],
        strain_name=arguments['<strain_name>'],
        depth_file=arguments['<depth_file>'],
        verbose=arguments['--verbose'],
        quiet=arguments['--quiet']
    )
