#!/usr/bin/env python
import argparse
import csv
import os
import re
import urllib.parse


def normalize_header(header, ncols):
    if len(header) < ncols:
        header = header + [f"col{i}" for i in range(len(header) + 1, ncols + 1)]
    elif len(header) > ncols:
        header = header[:ncols]
    return header


def find_col_idx(header, name):
    if not header:
        return None
    for idx, col in enumerate(header):
        if col.lower() == name:
            return idx
    return None


def strip_transcript_name(value):
    if not value:
        return ""
    name = value
    if "_" in name:
        name = name.split("_", 1)[1]
    if name.endswith(".mRNA"):
        name = name[:-5]
    return name


def format_aa_change(value, consequence):
    if not value:
        if consequence:
            return consequence
        return "unknown"
    m = re.match(r"(\d+)([A-Za-z*])>(\d+)([A-Za-z*])", value)
    if m:
        pos1, ref, pos2, alt = m.groups()
        if pos1 == pos2:
            return f"{ref}{pos1}{alt}"
    return value


def is_undetermined(row):
    if not row or len(row) < 2:
        return False
    sample = row[1]
    return sample.startswith("Undetermined")


def build_variant_id(row, header):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    gene = row[2] if len(row) > 2 else ""
    transcript_idx = find_col_idx(header, "transcript")
    strain_idx = find_col_idx(header, "strain")
    if strain_idx is None:
        strain_idx = find_col_idx(header, "chrom")
    pos_idx = find_col_idx(header, "pos")
    ref_idx = find_col_idx(header, "ref")
    alt_idx = find_col_idx(header, "alt")
    transcript = row[transcript_idx] if transcript_idx is not None and len(row) > transcript_idx else ""
    strain = row[strain_idx] if strain_idx is not None and len(row) > strain_idx else ""
    if "REF" in strain:
        strain = strain.split("REF", 1)[0]
    pos = row[pos_idx] if pos_idx is not None and len(row) > pos_idx else ""
    ref = row[ref_idx] if ref_idx is not None and len(row) > ref_idx else ""
    alt = row[alt_idx] if alt_idx is not None and len(row) > alt_idx else ""
    mut = f"{ref}{pos}{alt}" if ref and alt else pos
    return f"{run}:{sample}:{strain}:{gene}:{mut}"


def build_variant_effect_id(row, header):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    gene = row[2] if len(row) > 2 else ""
    transcript_idx = find_col_idx(header, "transcript")
    strain_idx = find_col_idx(header, "strain")
    if strain_idx is None:
        strain_idx = find_col_idx(header, "chrom")
    pos_idx = find_col_idx(header, "pos")
    ref_idx = find_col_idx(header, "ref")
    alt_idx = find_col_idx(header, "alt")
    aa_idx = find_col_idx(header, "amino_acid_change")
    consequence_idx = find_col_idx(header, "consequence")

    transcript = row[transcript_idx] if transcript_idx is not None and len(row) > transcript_idx else ""
    gene_label = strip_transcript_name(transcript) or gene
    strain = row[strain_idx] if strain_idx is not None and len(row) > strain_idx else ""
    if "REF" in strain:
        strain = strain.split("REF", 1)[0]
    pos = row[pos_idx] if pos_idx is not None and len(row) > pos_idx else ""
    ref = row[ref_idx] if ref_idx is not None and len(row) > ref_idx else ""
    alt = row[alt_idx] if alt_idx is not None and len(row) > alt_idx else ""
    mut = f"{ref}{pos}{alt}" if ref and alt else pos
    aa = row[aa_idx] if aa_idx is not None and len(row) > aa_idx else ""
    consequence = row[consequence_idx] if consequence_idx is not None and len(row) > consequence_idx else ""
    aa_label = format_aa_change(aa, consequence)
    return f"{run}:{sample}:{strain}:{gene_label}:{mut}:{aa_label}"


def decode_row(row, header, columns):
    if not columns or not header:
        return row
    header_map = {name.lower(): idx for idx, name in enumerate(header)}
    for name in columns:
        idx = header_map.get(name.lower())
        if idx is None or idx >= len(row):
            continue
        value = row[idx]
        if value:
            row[idx] = urllib.parse.unquote(value)
    return row


def rewrite_with_header(src, dest, id_builder=None, decode_cols=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        header = next(reader, None)
        if not header:
            return
        writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            if id_builder in (build_variant_effect_id, build_variant_id) and is_undetermined(row):
                continue
            row = decode_row(row, header, decode_cols)
            if id_builder:
                sample = id_builder(row, header)
            else:
                sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)


def rewrite_no_header(src, dest, header, id_builder=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        first = next(reader, None)
        if not first:
            return
        header = normalize_header(header, len(first))
        writer.writerow(['Sample'] + header)
        if id_builder == build_variant_id and is_undetermined(first):
            first = None
        if id_builder:
            if first is not None:
                sample = id_builder(first, header)
            else:
                sample = None
        else:
            sample = f"{first[0]}:{first[1]}" if len(first) > 1 else first[0]
        if first is not None:
            writer.writerow([sample] + first)
        for row in reader:
            if not row:
                continue
            if id_builder == build_variant_id and is_undetermined(row):
                continue
            if id_builder:
                sample = id_builder(row, header)
            else:
                sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare variant analysis tables for MultiQC.")
    parser.add_argument('--variants', required=True)
    parser.add_argument('--variants-out', required=True)
    parser.add_argument('--variant-effects', required=True)
    parser.add_argument('--variant-effects-out', required=True)
    parser.add_argument('--lineage-compare')
    parser.add_argument('--lineage-compare-out')
    args = parser.parse_args()

    rewrite_no_header(
        args.variants,
        args.variants_out,
        ['run', 'sample', 'gene', 'chrom', 'pos', 'id', 'ref', 'alt', 'qual', 'filter', 'info', 'format', 'sample_field'],
        id_builder=build_variant_id,
    )
    rewrite_with_header(
        args.variant_effects,
        args.variant_effects_out,
        id_builder=build_variant_effect_id,
        decode_cols=['gene', 'transcript'],
    )
    if args.lineage_compare and args.lineage_compare_out:
        rewrite_with_header(
            args.lineage_compare,
            args.lineage_compare_out,
            id_builder=build_variant_id,
        )


if __name__ == '__main__':
    main()
