#!/usr/bin/env python
import argparse
import csv
import shutil


def prepare(input_path, output_path, id_builder):
    with open(input_path, newline='') as handle:
        reader = csv.reader(handle, delimiter='\t')
        rows = list(reader)
    if not rows:
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\t')
            writer.writerow(['ID', 'database_id', 'gene', 'chrom', 'pos', 'ref', 'alt'])
        return
    header = rows[0]
    start_idx = 1 if header and header[0] in ('lineage', 'database_id', 'query_id', 'sample') else 0
    if start_idx == 0:
        header = ['database_id', 'gene', 'chrom', 'pos', 'ref', 'alt'] + header[6:]
    else:
        header = header[:]
        if header[0] in ('lineage', 'query_id', 'sample'):
            header[0] = 'database_id'
    with open(output_path, 'w', newline='') as out:
        writer = csv.writer(out, delimiter='\t')
        writer.writerow(['ID'] + header)
        for row in rows[start_idx:]:
            if len(row) < 6:
                continue
            database_id, gene, chrom, pos, ref, alt = row[:6]
            extra = row[6:]
            row_id = id_builder(database_id, gene, pos, ref, alt)
            writer.writerow([row_id, database_id, gene, chrom, pos, ref, alt] + extra)


def build_id(database_id, gene, pos, ref, alt):
    return f"{database_id}:{gene}:{ref}{pos}{alt}"


def prepare_samples(input_path, output_path):
    with open(input_path, newline='') as handle:
        reader = csv.reader(handle, delimiter='\t')
        rows = list(reader)
    if not rows:
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\t')
            writer.writerow(['ID', 'run', 'sample', 'gene', 'chrom', 'pos', 'ref', 'alt'])
        return
    header = rows[0]
    start_idx = 1 if header and header[0] == 'run' else 0
    if start_idx == 0:
        header = ['run', 'sample', 'gene', 'chrom', 'pos', 'ref', 'alt'] + header[7:]
    with open(output_path, 'w', newline='') as out:
        writer = csv.writer(out, delimiter='\t')
        writer.writerow(['ID'] + header)
        for row in rows[start_idx:]:
            if len(row) < 7:
                continue
            run, sample, gene, chrom, pos, ref, alt = row[:7]
            extra = row[7:]
            row_id = f"{run}:{sample}:{gene}:{ref}{pos}{alt}"
            writer.writerow([row_id, run, sample, gene, chrom, pos, ref, alt] + extra)


def prepare_set_comparison(input_path, output_path, label_field):
    with open(input_path, newline='') as handle:
        reader = csv.reader(handle, delimiter='\t')
        rows = list(reader)
    if not rows:
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\t')
            writer.writerow(['ID', 'run', 'sample', label_field])
        return
    header = rows[0]
    start_idx = 1 if header and header[0] == 'run' else 0
    if start_idx == 0:
        header = ['run', 'sample', label_field] + header[3:]
    with open(output_path, 'w', newline='') as out:
        writer = csv.writer(out, delimiter='\t')
        writer.writerow(['ID'] + header)
        for row in rows[start_idx:]:
            if len(row) < 3:
                continue
            run, sample, label = row[:3]
            extra = row[3:]
            row_id = f"{run}:{sample}:{label}"
            writer.writerow([row_id, run, sample, label] + extra)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare variant database tables for MultiQC.")
    parser.add_argument('--database-snps', required=True)
    parser.add_argument('--database-snps-out', required=True)
    parser.add_argument('--database-lineage-comparison', required=True)
    parser.add_argument('--database-lineage-comparison-out', required=True)
    parser.add_argument('--database-sample-comparison', required=True)
    parser.add_argument('--database-sample-comparison-out', required=True)
    parser.add_argument('--samples-vs-database', required=True)
    parser.add_argument('--samples-vs-database-out', required=True)
    parser.add_argument('--samples-vs-database-sets', required=True)
    parser.add_argument('--samples-vs-database-sets-out', required=True)
    parser.add_argument('--samples-vs-lineage-sets', required=True)
    parser.add_argument('--samples-vs-lineage-sets-out', required=True)
    parser.add_argument('--hpv16-e6e7-summary', required=True)
    parser.add_argument('--hpv16-e6e7-summary-out', required=True)
    args = parser.parse_args()

    prepare(args.database_snps, args.database_snps_out, build_id)
    prepare(args.database_lineage_comparison, args.database_lineage_comparison_out, build_id)
    prepare(args.database_sample_comparison, args.database_sample_comparison_out, build_id)
    prepare_samples(args.samples_vs_database, args.samples_vs_database_out)
    prepare_set_comparison(args.samples_vs_database_sets, args.samples_vs_database_sets_out, 'database_id')
    prepare_set_comparison(args.samples_vs_lineage_sets, args.samples_vs_lineage_sets_out, 'lineage')
    shutil.copyfile(args.hpv16_e6e7_summary, args.hpv16_e6e7_summary_out)


if __name__ == '__main__':
    main()
