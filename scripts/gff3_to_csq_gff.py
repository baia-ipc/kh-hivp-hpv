#!/usr/bin/env python3
"""
Build a bcftools-csq-friendly GFF3 from PaVE GFF files.

This script emits only gene, mRNA, and CDS features with consistent Parent
relationships, and strips FASTA sections.
"""

import argparse
import glob
import os
from typing import Dict, List


def parse_attrs(attr_str: str) -> Dict[str, str]:
    attrs = {}
    for part in attr_str.split(";"):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            attrs[k] = v
    return attrs


def format_attrs(attrs: Dict[str, str]) -> str:
    return ";".join([f"{k}={v}" for k, v in attrs.items()])


def emit_line(fields: List[str]) -> str:
    return "\t".join(fields)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gff_dir", help="Directory containing PaVE GFF/GFF3 files")
    ap.add_argument("-o", "--output", required=True, help="Output GFF3 path")
    ap.add_argument("--fasta", help="Reference FASTA to normalize seqids")
    args = ap.parse_args()

    gff_files = []
    for pat in ("*.gff", "*.gff3"):
        gff_files.extend(sorted(glob.glob(os.path.join(args.gff_dir, pat))))
    if not gff_files:
        raise SystemExit(f"No GFF files found under {args.gff_dir}")

    # Build seqid mapping from FASTA (prefix -> full id)
    seqid_map = {}
    if args.fasta:
        with open(args.fasta, "r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                if not line.startswith(">"):
                    continue
                header = line[1:].strip().split()[0]
                key = header.split("|")[0]
                seqid_map[key] = header

    allowed_prefix = "HPV16REF"
    seen_ids = set()
    gene_bounds = {}

    with open(args.output, "w", encoding="utf-8") as out:
        out.write("##gff-version 3\n")
        for gff in gff_files:
            in_fasta = False
            for line in open(gff, "r", encoding="utf-8", errors="ignore"):
                line = line.rstrip("\n")
                if line.startswith("##FASTA"):
                    in_fasta = True
                    continue
                if in_fasta or line.startswith(">"):
                    continue
                if not line or line.startswith("#"):
                    if line.startswith("##sequence-region"):
                        if seqid_map:
                            parts = line.split()
                            if len(parts) >= 2:
                                seqid = parts[1]
                                mapped = seqid_map.get(seqid, seqid)
                                if mapped.split("|")[0] != allowed_prefix:
                                    continue
                                parts[1] = mapped
                                line = " ".join(parts)
                        else:
                            if parts[1].split("|")[0] != allowed_prefix:
                                continue
                        out.write(line + "\n")
                    continue
                parts = line.split("\t")
                if len(parts) < 9:
                    continue
                seqid, source, ftype, start, end, score, strand, phase, attrs = parts
                if seqid_map:
                    seqid = seqid_map.get(seqid, seqid)
                if seqid.split("|")[0] != allowed_prefix:
                    continue
                attrs_dict = parse_attrs(attrs)

                parts[0] = seqid
                if ftype == "gene":
                    gene_id = attrs_dict.get("ID")
                    if gene_id:
                        if gene_id in seen_ids:
                            continue
                        seen_ids.add(gene_id)
                        gene_bounds[gene_id] = (int(start), int(end))
                        out.write(emit_line(parts) + "\n")
                        mrna_attrs = {
                            "ID": f"{gene_id}.mRNA",
                            "Parent": gene_id,
                        }
                        # keep name if present
                        if "Name" in attrs_dict:
                            mrna_attrs["Name"] = attrs_dict["Name"]
                        mrna_id = mrna_attrs["ID"]
                        if mrna_id in seen_ids:
                            continue
                        seen_ids.add(mrna_id)
                        mrna = [
                            seqid, source, "mRNA", start, end, score, strand, phase,
                            format_attrs(mrna_attrs),
                        ]
                        out.write(emit_line(mrna) + "\n")
                elif ftype == "CDS":
                    parent = attrs_dict.get("Parent")
                    if not parent:
                        continue
                    if parent not in gene_bounds:
                        continue
                    gene_start, gene_end = gene_bounds[parent]
                    if int(start) < gene_start or int(end) > gene_end:
                        continue
                    attrs_dict["Parent"] = f"{parent}.mRNA"
                    cds_id = attrs_dict.get("ID")
                    if cds_id:
                        if cds_id in seen_ids:
                            continue
                        seen_ids.add(cds_id)
                    parts[8] = format_attrs(attrs_dict)
                    out.write(emit_line(parts) + "\n")


if __name__ == "__main__":
    main()
