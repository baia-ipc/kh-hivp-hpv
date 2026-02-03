#!/usr/bin/env python3
"""
Summarize HPV16 E6/E7 variants for samples, database accessions, and lineages.

Outputs a two-column TSV with ID and a comma-separated list of variants
formatted as refposalt(AAchange) for missense and refposalt(syn) for synonymous.
"""

import argparse
import csv
import os
import re
import urllib.parse
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-effects", required=True, help="E6/E7 variant effects TSV")
    parser.add_argument("--database-snps", required=True, help="Database SNPs TSV")
    parser.add_argument("--lineage-snps", required=True, help="Lineage SNPs TSV")
    parser.add_argument("--sample-list", required=True, help="Samples metadata TSV")
    parser.add_argument("--database-fasta", required=True, help="Database HPV16 FASTA")
    parser.add_argument("--lineage-fasta", required=True, help="HPV16 lineage FASTA")
    parser.add_argument("--ref-fasta", required=True, help="Reference FASTA")
    parser.add_argument("--bed-dir", required=True, help="Directory with pave_hsa.E6/E7.bed")
    parser.add_argument("--output", required=True, help="Output TSV path")
    return parser.parse_args()


def decode_field(value):
    return urllib.parse.unquote(value) if value else value


def normalize_aa_change(aa_change):
    if not aa_change:
        return ""
    aa_change = aa_change.strip()
    # Normalize forms like 25D>25E to D25E
    match = re.match(r"^(\d+)([A-Za-z\*])>(\d+)?([A-Za-z\*])$", aa_change)
    if match:
        pos = match.group(1)
        ref = match.group(2)
        alt = match.group(4)
        return f"{ref}{pos}{alt}"
    return aa_change


def choose_variant(existing, candidate):
    if existing is None:
        return candidate
    existing_cons = existing.get("consequence", "")
    candidate_cons = candidate.get("consequence", "")
    if "missense" in candidate_cons and "missense" not in existing_cons:
        return candidate
    if "synonymous" in candidate_cons and "synonymous" not in existing_cons:
        return candidate
    return existing


def load_sample_effects(path):
    variants = defaultdict(dict)
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            chrom = row.get("chrom", "")
            gene = row.get("gene", "")
            if not chrom.startswith("HPV16REF"):
                continue
            if gene not in {"E6", "E7"}:
                continue
            sample = row.get("sample")
            if not sample:
                continue
            try:
                pos = int(row.get("pos"))
            except (TypeError, ValueError):
                continue
            ref = row.get("ref", "")
            alt = row.get("alt", "")
            consequence = row.get("Consequence", "")
            aa_change = normalize_aa_change(row.get("amino_acid_change", ""))
            key = (gene, pos, ref, alt)
            candidate = {
                "gene": gene,
                "pos": pos,
                "ref": ref,
                "alt": alt,
                "consequence": consequence,
                "aa_change": aa_change,
            }
            existing = variants[sample].get(key)
            variants[sample][key] = choose_variant(existing, candidate)
    return {sample: list(vals.values()) for sample, vals in variants.items()}

def load_sample_list(path):
    samples = []
    seen = set()
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            sample_id = parts[2].strip()
            if not sample_id:
                continue
            if sample_id in seen:
                continue
            seen.add(sample_id)
            samples.append(sample_id)
    return samples

def load_fasta_ids(path):
    ids = []
    seen = set()
    for name, _seq in read_fasta(path):
        if name in seen:
            continue
        seen.add(name)
        ids.append(name)
    return ids


def parse_snp_table(path):
    rows = []
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            try:
                pos = int(row.get("pos"))
            except (TypeError, ValueError):
                continue
            chrom = row.get("chrom", "")
            gene = row.get("gene", "")
            if not chrom.startswith("HPV16REF"):
                continue
            if gene not in {"E6", "E7"}:
                continue
            rows.append(
                {
                    "id": row.get("lineage") or row.get("database_id") or row.get("cambodia_id") or row.get("query_id") or row.get("sample"),
                    "gene": gene,
                    "chrom": chrom,
                    "pos": pos,
                    "ref": row.get("ref", ""),
                    "alt": row.get("alt", ""),
                }
            )
    return rows


CODON_TABLE = {
    "TTT": "F", "TTC": "F", "TTA": "L", "TTG": "L",
    "CTT": "L", "CTC": "L", "CTA": "L", "CTG": "L",
    "ATT": "I", "ATC": "I", "ATA": "I", "ATG": "M",
    "GTT": "V", "GTC": "V", "GTA": "V", "GTG": "V",
    "TCT": "S", "TCC": "S", "TCA": "S", "TCG": "S",
    "CCT": "P", "CCC": "P", "CCA": "P", "CCG": "P",
    "ACT": "T", "ACC": "T", "ACA": "T", "ACG": "T",
    "GCT": "A", "GCC": "A", "GCA": "A", "GCG": "A",
    "TAT": "Y", "TAC": "Y", "TAA": "*", "TAG": "*",
    "CAT": "H", "CAC": "H", "CAA": "Q", "CAG": "Q",
    "AAT": "N", "AAC": "N", "AAA": "K", "AAG": "K",
    "GAT": "D", "GAC": "D", "GAA": "E", "GAG": "E",
    "TGT": "C", "TGC": "C", "TGA": "*", "TGG": "W",
    "CGT": "R", "CGC": "R", "CGA": "R", "CGG": "R",
    "AGT": "S", "AGC": "S", "AGA": "R", "AGG": "R",
    "GGT": "G", "GGC": "G", "GGA": "G", "GGG": "G",
}


def read_fasta(path, prefix=None):
    name = None
    seq = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if name is not None:
                    yield name, "".join(seq)
                name = line[1:].split()[0]
                seq = []
            else:
                seq.append(line)
        if name is not None:
            yield name, "".join(seq)


def load_ref_sequence(ref_fasta, prefix="HPV16REF"):
    for name, seq in read_fasta(ref_fasta):
        if name.startswith(prefix):
            return name, seq
    raise SystemExit(f"Reference sequence not found for prefix {prefix} in {ref_fasta}")


def load_gene_bounds(bed_dir, ref_name):
    bounds = {}
    for gene in ("E6", "E7"):
        bed_path = os.path.join(bed_dir, f"pave_hsa.{gene}.bed")
        if not os.path.exists(bed_path):
            continue
        with open(bed_path) as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                chrom, start, end, name = line.split("\t")[:4]
                if chrom != ref_name:
                    continue
                bounds[gene] = (int(start), int(end))
                break
    return bounds


def translate_codon(codon):
    return CODON_TABLE.get(codon.upper(), "X")


def annotate_variant(variant, ref_seq, gene_bounds):
    gene = variant["gene"]
    if gene not in gene_bounds:
        return {"consequence": "", "aa_change": ""}
    start, end = gene_bounds[gene]
    pos0 = variant["pos"] - 1
    if pos0 < start or pos0 >= end:
        return {"consequence": "", "aa_change": ""}
    offset = pos0 - start
    codon_index = offset // 3
    codon_pos = offset % 3
    codon_start = start + codon_index * 3
    codon = ref_seq[codon_start:codon_start + 3].upper()
    if len(codon) != 3 or any(base not in "ACGT" for base in codon):
        return {"consequence": "", "aa_change": ""}
    alt = variant["alt"].upper()
    if alt not in "ACGT":
        return {"consequence": "", "aa_change": ""}
    alt_codon = list(codon)
    alt_codon[codon_pos] = alt
    alt_codon = "".join(alt_codon)
    aa_ref = translate_codon(codon)
    aa_alt = translate_codon(alt_codon)
    aa_pos = codon_index + 1
    if aa_ref == aa_alt:
        consequence = "synonymous"
        aa_change = ""
    else:
        consequence = "missense"
        aa_change = f"{aa_ref}{aa_pos}{aa_alt}"
    return {"consequence": consequence, "aa_change": aa_change}


def annotate_snps_by_id(snps_by_id, ref_seq, gene_bounds):
    annotated_by_id = {}
    for entity_id, snps in snps_by_id.items():
        enriched = []
        for variant in snps:
            info = annotate_variant(variant, ref_seq, gene_bounds)
            enriched.append(
                {
                    "gene": variant["gene"],
                    "pos": variant["pos"],
                    "ref": variant["ref"],
                    "alt": variant["alt"],
                    "consequence": info.get("consequence", ""),
                    "aa_change": info.get("aa_change", ""),
                }
            )
        annotated_by_id[entity_id] = enriched
    return annotated_by_id


def build_variant_label(variant):
    ref = variant.get("ref", "")
    alt = variant.get("alt", "")
    pos = variant.get("pos")
    consequence = (variant.get("consequence") or "").lower()
    aa_change = variant.get("aa_change", "")
    if "synonymous" in consequence:
        suffix = "syn"
    elif "missense" in consequence:
        suffix = aa_change or "missense"
    elif consequence:
        suffix = consequence
    else:
        suffix = ""
    if suffix:
        return f"{ref}{pos}{alt}({suffix})"
    return f"{ref}{pos}{alt}"


def combine_positions(variants):
    by_pos = {v["pos"]: v for v in variants}
    if 143 in by_pos and 145 in by_pos:
        v143 = by_pos[143]
        v145 = by_pos[145]
        aa_label = v143.get("aa_change") or "syn"
        combined = {
            "pos": 143,
            "label": f"{v143['ref']}143{v143['alt']}+{v145['ref']}145{v145['alt']}({aa_label})",
        }
        remaining = [v for v in variants if v["pos"] not in {143, 145}]
        remaining.append(combined)
        return remaining
    return variants


def labels_for_entity(variants):
    variants = sorted(variants, key=lambda v: v.get("pos", 0))
    combined = combine_positions(variants)
    labels = []
    for v in sorted(combined, key=lambda v: v.get("pos", 0)):
        label = v.get("label") or build_variant_label(v)
        labels.append(label)
    return labels

def labels_by_gene(variants):
    by_gene = {"E6": [], "E7": []}
    for variant in variants:
        gene = variant.get("gene")
        if gene not in by_gene:
            continue
        by_gene[gene].append(variant)
    labels = {}
    for gene, items in by_gene.items():
        if not items:
            labels[gene] = "-"
            continue
        gene_labels = labels_for_entity(items)
        labels[gene] = ", ".join(gene_labels) if gene_labels else "-"
    return labels


def main():
    args = parse_args()
    ref_name, ref_seq = load_ref_sequence(args.ref_fasta)
    gene_bounds = load_gene_bounds(args.bed_dir, ref_name)

    sample_variants = load_sample_effects(args.sample_effects)
    sample_ids = load_sample_list(args.sample_list)
    database_ids = load_fasta_ids(args.database_fasta)
    lineage_ids = load_fasta_ids(args.lineage_fasta)

    database_rows = parse_snp_table(args.database_snps)
    lineage_rows = parse_snp_table(args.lineage_snps)

    database_by_id = defaultdict(list)
    for row in database_rows:
        if row["id"]:
            database_by_id[row["id"]].append(row)
    lineage_by_id = defaultdict(list)
    for row in lineage_rows:
        if row["id"]:
            lineage_by_id[row["id"]].append(row)

    database_effects = annotate_snps_by_id(database_by_id, ref_seq, gene_bounds)
    lineage_effects = annotate_snps_by_id(lineage_by_id, ref_seq, gene_bounds)

    with open(args.output, "w", newline="") as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow(["ID", "E6_variants", "E7_variants"])

        for sample_id in sample_ids:
            variants = sample_variants.get(sample_id, [])
            labels = labels_by_gene(variants)
            writer.writerow([f"3__{sample_id}", labels["E6"], labels["E7"]])

        for accession in database_ids:
            variants = database_effects.get(accession, [])
            labels = labels_by_gene(variants)
            # remove HPV16_ prefix from accession
            if accession.startswith("HPV16_"):
                accession = accession[len("HPV16_") :]
            writer.writerow([f"2__{accession}", labels["E6"], labels["E7"]])

        for lineage in lineage_ids:
            variants = lineage_effects.get(lineage, [])
            labels = labels_by_gene(variants)
            writer.writerow([f"1__{lineage}", labels["E6"], labels["E7"]])


if __name__ == "__main__":
    main()
