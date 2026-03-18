#!/usr/bin/env python3
"""Validate candidate recombinant signals against mapped reads."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

from Bio import SeqIO

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import read_tsv, write_tsv  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--candidates-tsv", required=True)
    parser.add_argument("--gard-summary-json", required=True)
    parser.add_argument("--mapping-outdir", required=True)
    parser.add_argument("--reference-fasta", required=True)
    parser.add_argument("--reference-chrom", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--min-depth", type=int, default=30)
    parser.add_argument("--min-major-af", type=float, default=0.90)
    parser.add_argument("--output-tsv", required=True)
    return parser.parse_args()


def aligned_to_sample_position(sequence: str, aligned_pos: int) -> int | None:
    ungapped = 0
    for idx, base in enumerate(sequence, start=1):
        if base != "-":
            ungapped += 1
        if idx == aligned_pos:
            return ungapped if base != "-" else None
    return None


def query_site(
    bam_path: Path,
    reference_fasta: Path,
    chrom: str,
    pos: int,
) -> tuple[int, dict[str, int]]:
    region = f"{chrom}:{pos}-{pos}"
    cmd = [
        "samtools",
        "mpileup",
        "-aa",
        "-f",
        str(reference_fasta),
        "-r",
        region,
        str(bam_path),
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if completed.returncode != 0 or not completed.stdout.strip():
        return 0, {}
    fields = completed.stdout.strip().split("\t")
    if len(fields) < 5:
        return 0, {}
    depth = int(fields[3])
    pileup = fields[4]
    counts = {"A": 0, "C": 0, "G": 0, "T": 0}
    ref = fields[2].upper()
    idx = 0
    while idx < len(pileup):
        base = pileup[idx]
        if base == "^":
            idx += 2
            continue
        if base == "$":
            idx += 1
            continue
        if base in "+-":
            idx += 1
            digits = []
            while idx < len(pileup) and pileup[idx].isdigit():
                digits.append(pileup[idx])
                idx += 1
            skip = int("".join(digits)) if digits else 0
            idx += skip
            continue
        if base in ".,":  # reference match
            counts[ref] = counts.get(ref, 0) + 1
        else:
            nuc = base.upper()
            if nuc in counts:
                counts[nuc] += 1
        idx += 1
    return depth, counts


def main() -> int:
    args = parse_args()
    manifest_rows = {row["normalized_record_id"]: row for row in read_tsv(Path(args.manifest_tsv))}
    candidate_rows = [row for row in read_tsv(Path(args.candidates_tsv)) if row.get("eligible_sample_candidate") == "yes"]
    alignment = {record.id: str(record.seq).upper() for record in SeqIO.parse(args.alignment, "fasta")}
    mapping_outdir = Path(args.mapping_outdir)
    reference_fasta = Path(args.reference_fasta)

    rows: list[dict[str, Any]] = []
    for candidate in candidate_rows:
        child = candidate["candidate_record_id"]
        parent_a = candidate["parent_major_record_id"]
        parent_b = candidate["parent_minor_record_id"]
        sample_id = manifest_rows.get(child, {}).get("sample_id", candidate.get("candidate_sample_id", child))
        bam_path = mapping_outdir / f"{sample_id}.bam"
        if not bam_path.exists():
            rows.append(
                {
                    "analysis_group": args.analysis_group,
                    "hpv_type": args.hpv_type,
                    "candidate_id": candidate["candidate_id"],
                    "candidate_record_id": child,
                    "sample_id": sample_id,
                    "informative_site_count": 0,
                    "left_site_count": 0,
                    "right_site_count": 0,
                    "sites_passing_depth": 0,
                    "sites_passing_major_af": 0,
                    "mixed_or_ambiguous_sites": 0,
                    "read_validation_status": "missing_bam",
                    "notes": f"BAM not found at {bam_path}",
                }
            )
            continue

        try:
            breakpoint_site = int(candidate["candidate_breakpoint_site"])
        except (TypeError, ValueError):
            breakpoint_site = max(1, len(alignment.get(child, "")) // 2)

        child_seq = alignment.get(child, "")
        parent_a_seq = alignment.get(parent_a, "")
        parent_b_seq = alignment.get(parent_b, "")
        informative_sites: list[tuple[int, str, str]] = []
        for idx, (child_base, a_base, b_base) in enumerate(zip(child_seq, parent_a_seq, parent_b_seq), start=1):
            if "-" in {child_base, a_base, b_base} or "N" in {child_base, a_base, b_base}:
                continue
            if a_base == b_base:
                continue
            if child_base not in {a_base, b_base}:
                continue
            informative_sites.append((idx, a_base, b_base))

        left_sites = [site for site in informative_sites if site[0] <= breakpoint_site]
        right_sites = [site for site in informative_sites if site[0] > breakpoint_site]

        passing_depth = 0
        passing_major_af = 0
        ambiguous = 0
        queried = 0

        for aligned_pos, parent_a_base, parent_b_base in informative_sites:
            sample_pos = aligned_to_sample_position(child_seq, aligned_pos)
            if sample_pos is None:
                continue
            depth, counts = query_site(bam_path, reference_fasta, args.reference_chrom, sample_pos)
            queried += 1
            if depth >= args.min_depth:
                passing_depth += 1
            child_base = child_seq[aligned_pos - 1]
            major_count = counts.get(child_base, 0)
            major_af = (major_count / depth) if depth else 0.0
            if depth >= args.min_depth and major_af >= args.min_major_af:
                passing_major_af += 1
            elif depth >= args.min_depth:
                ambiguous += 1

        status = "pass"
        if queried == 0:
            status = "not_evaluable"
        elif ambiguous >= 2:
            status = "mixed_or_ambiguous"
        elif passing_depth < max(1, queried) or passing_major_af < max(1, queried):
            status = "fail"

        rows.append(
            {
                "analysis_group": args.analysis_group,
                "hpv_type": args.hpv_type,
                "candidate_id": candidate["candidate_id"],
                "candidate_record_id": child,
                "sample_id": sample_id,
                "informative_site_count": queried,
                "left_site_count": len(left_sites),
                "right_site_count": len(right_sites),
                "sites_passing_depth": passing_depth,
                "sites_passing_major_af": passing_major_af,
                "mixed_or_ambiguous_sites": ambiguous,
                "read_validation_status": status,
                "notes": "",
            }
        )

    write_tsv(
        Path(args.output_tsv),
        rows,
        [
            "analysis_group",
            "hpv_type",
            "candidate_id",
            "candidate_record_id",
            "sample_id",
            "informative_site_count",
            "left_site_count",
            "right_site_count",
            "sites_passing_depth",
            "sites_passing_major_af",
            "mixed_or_ambiguous_sites",
            "read_validation_status",
            "notes",
        ],
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
