#!/usr/bin/env python3
"""
Summarize HPV16 E6/E7 variants for samples, Cambodia accessions, and lineages.

Outputs a two-column TSV with ID and a comma-separated list of variants
formatted as refposalt(AAchange) for missense and refposalt(syn) for synonymous.
"""

import argparse
import csv
import os
import re
import subprocess
import tempfile
import urllib.parse
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-effects", required=True, help="E6/E7 variant effects TSV")
    parser.add_argument("--cambodia-snps", required=True, help="Cambodia SNPs TSV")
    parser.add_argument("--lineage-snps", required=True, help="Lineage SNPs TSV")
    parser.add_argument("--ref-fasta", required=True, help="Reference FASTA")
    parser.add_argument("--gff3-dir", required=True, help="Directory with PaVE GFF/GFF3 files")
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
            key = (pos, ref, alt)
            candidate = {
                "pos": pos,
                "ref": ref,
                "alt": alt,
                "consequence": consequence,
                "aa_change": aa_change,
            }
            existing = variants[sample].get(key)
            variants[sample][key] = choose_variant(existing, candidate)
    return {sample: list(vals.values()) for sample, vals in variants.items()}


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
                    "id": row.get("lineage") or row.get("cambodia_id") or row.get("query_id") or row.get("sample"),
                    "gene": gene,
                    "chrom": chrom,
                    "pos": pos,
                    "ref": row.get("ref", ""),
                    "alt": row.get("alt", ""),
                }
            )
    return rows


def ensure_fai(ref_fasta):
    if not os.path.exists(ref_fasta + ".fai"):
        subprocess.run(["samtools", "faidx", ref_fasta], check=True)


def build_csq_gff(gff3_dir, ref_fasta, output_path, script_dir):
    subprocess.run(
        [
            os.path.join(script_dir, "gff3_to_csq_gff.py"),
            gff3_dir,
            "-o",
            output_path,
            "--fasta",
            ref_fasta,
        ],
        check=True,
    )


def parse_bcsq_format(line):
    match = re.search(r"Format: ([^\">]+)", line)
    if not match:
        return []
    return [field.strip() for field in match.group(1).split("|") if field.strip()]


def parse_info(info_str):
    info = {}
    for part in info_str.split(";"):
        if "=" in part:
            key, value = part.split("=", 1)
            info[key] = value
        else:
            info[part] = True
    return info


def annotate_snps(snps, ref_fasta, gff_path):
    if not snps:
        return []
    vcf_lines = ["##fileformat=VCFv4.2", "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"]
    for row in snps:
        vcf_lines.append(
            f"{row['chrom']}\t{row['pos']}\t.\t{row['ref']}\t{row['alt']}\t.\tPASS\t."
        )
    with tempfile.NamedTemporaryFile(mode="w", suffix=".vcf", delete=False) as tmp_vcf:
        tmp_vcf.write("\n".join(vcf_lines) + "\n")
        vcf_path = tmp_vcf.name
    try:
        cmd = ["bcftools", "csq", "-f", ref_fasta, "-g", gff_path, "-Ov", vcf_path]
        output = subprocess.check_output(cmd, text=True)
    finally:
        os.unlink(vcf_path)

    bcsq_fields = []
    annotated = {}
    for line in output.splitlines():
        if line.startswith("##INFO=<ID=BCSQ"):
            bcsq_fields = parse_bcsq_format(line)
            continue
        if line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 8:
            continue
        chrom, pos, _vid, ref, alt, _qual, _filt, info_str = fields[:8]
        info = parse_info(info_str)
        if "BCSQ" not in info:
            continue
        pos_int = int(pos)
        key = (chrom, pos_int, ref, alt)
        bcsq_entries = info["BCSQ"].split(",")
        entries = []
        for entry in bcsq_entries:
            parts = entry.split("|")
            if bcsq_fields:
                if len(parts) < len(bcsq_fields):
                    parts += [""] * (len(bcsq_fields) - len(parts))
                data = dict(zip(bcsq_fields, parts))
            else:
                data = {"Consequence": entry}
            entries.append(data)
        annotated[key] = entries
    return annotated


def select_bcsq_entry(annotated, variant):
    key = (variant["chrom"], variant["pos"], variant["ref"], variant["alt"])
    entries = annotated.get(key)
    if not entries:
        return None
    for data in entries:
        if "gene" in data:
            gene_val = decode_field(data.get("gene", ""))
            if gene_val == variant["gene"]:
                return data
    for data in entries:
        if "gene" in data:
            gene_val = decode_field(data.get("gene", ""))
            gene_val_norm = gene_val.replace("*", "")
            if gene_val_norm == variant["gene"]:
                return data
    return entries[0]


def annotate_snps_by_id(snps_by_id, ref_fasta, gff_path):
    annotated_by_id = {}
    for entity_id, snps in snps_by_id.items():
        annotated = annotate_snps(snps, ref_fasta, gff_path)
        enriched = []
        for variant in snps:
            data = select_bcsq_entry(annotated, variant)
            consequence = ""
            aa_change = ""
            if data:
                consequence = data.get("Consequence", "") or data.get("consequence", "")
                aa_change = normalize_aa_change(data.get("amino_acid_change", ""))
            enriched.append(
                {
                    "pos": variant["pos"],
                    "ref": variant["ref"],
                    "alt": variant["alt"],
                    "consequence": consequence,
                    "aa_change": aa_change,
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


def main():
    args = parse_args()
    script_dir = os.path.dirname(os.path.abspath(__file__))

    ensure_fai(args.ref_fasta)

    with tempfile.TemporaryDirectory(prefix="hpv16_summary_") as tmpdir:
        gff_path = os.path.join(tmpdir, "csq.gff3")
        build_csq_gff(args.gff3_dir, args.ref_fasta, gff_path, script_dir)

        sample_variants = load_sample_effects(args.sample_effects)

        cambodia_rows = parse_snp_table(args.cambodia_snps)
        lineage_rows = parse_snp_table(args.lineage_snps)

        cambodia_by_id = defaultdict(list)
        for row in cambodia_rows:
            if row["id"]:
                cambodia_by_id[row["id"]].append(row)
        lineage_by_id = defaultdict(list)
        for row in lineage_rows:
            if row["id"]:
                lineage_by_id[row["id"]].append(row)

        cambodia_effects = annotate_snps_by_id(cambodia_by_id, args.ref_fasta, gff_path)
        lineage_effects = annotate_snps_by_id(lineage_by_id, args.ref_fasta, gff_path)

        with open(args.output, "w", newline="") as out:
            writer = csv.writer(out, delimiter="\t")
            writer.writerow(["ID", "variants"])

            for sample_id in sorted(sample_variants):
                labels = labels_for_entity(sample_variants[sample_id])
                writer.writerow([sample_id, ", ".join(labels) if labels else "none"])

            for accession in sorted(cambodia_effects):
                labels = labels_for_entity(cambodia_effects[accession])
                writer.writerow([accession, ", ".join(labels) if labels else "none"])

            for lineage in sorted(lineage_effects):
                labels = labels_for_entity(lineage_effects[lineage])
                writer.writerow([lineage, ", ".join(labels) if labels else "none"])


if __name__ == "__main__":
    main()
