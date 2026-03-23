#!/usr/bin/env python3
"""Run OpenRDP on an aligned FASTA and emit sample-level candidate tables."""

from __future__ import annotations

import argparse
import csv
import json
import math
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--methods", nargs="+", required=True)
    parser.add_argument("--pvalue-threshold", type=float, default=0.01)
    parser.add_argument("--min-segment-length", type=int, default=500)
    parser.add_argument("--sanitize-ambiguity-bases", action="store_true")
    parser.add_argument("--output-candidates-tsv", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--output-log", required=True)
    parser.add_argument("--output-csv", required=True)
    return parser.parse_args()


def parse_method_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists() or path.stat().st_size == 0:
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def format_pvalue(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:.12g}"


def sanitize_alignment_for_openrdp(input_path: Path) -> tuple[Path, dict[str, int]]:
    """Rewrite unsupported IUPAC symbols to N while preserving alignment length."""
    allowed = set("ATGCN-")
    replacements: Counter[str] = Counter()
    output_path = input_path.with_suffix(input_path.suffix + ".openrdp.fa")

    with input_path.open("r", encoding="utf-8") as src, output_path.open("w", encoding="utf-8") as dst:
        for raw_line in src:
            if raw_line.startswith(">"):
                dst.write(raw_line)
                continue
            sequence = raw_line.rstrip("\n\r")
            sanitized_chars: list[str] = []
            for char in sequence:
                upper = char.upper()
                if upper in allowed:
                    sanitized_chars.append(upper)
                else:
                    sanitized_chars.append("N")
                    replacements[upper] += 1
            dst.write("".join(sanitized_chars) + "\n")

    return output_path, dict(sorted(replacements.items()))


def build_candidates(
    raw_rows: list[dict[str, str]],
    manifest_rows: dict[str, dict[str, str]],
    *,
    analysis_group: str,
    hpv_type: str,
    pvalue_threshold: float,
    min_segment_length: int,
) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for idx, row in enumerate(raw_rows, start=1):
        recombinant = row.get("Recombinant", "").strip()
        parent1 = row.get("Parent1", "").strip()
        parent2 = row.get("Parent2", "").strip()
        method = row.get("Method", "").strip()
        start_raw = row.get("Start", "").strip()
        end_raw = row.get("End", "").strip()
        pvalue_raw = row.get("Pvalue", "").strip()

        candidate_meta = manifest_rows.get(recombinant, {})
        candidate_role = candidate_meta.get("sequence_role", "unknown")

        try:
            start = int(start_raw)
            end = int(end_raw)
        except ValueError:
            start = 0
            end = 0

        try:
            pvalue = float(pvalue_raw)
        except ValueError:
            pvalue = None

        segment_length = max(0, end - start + 1) if start and end else 0
        breakpoint_site = math.floor((start + end) / 2) if start and end else ""
        candidate_breakpoints = ",".join(str(value) for value in [start, end] if value)
        passes_pvalue = pvalue is not None and pvalue <= pvalue_threshold
        passes_segment = segment_length >= min_segment_length

        candidates.append(
            {
                "analysis_group": analysis_group,
                "hpv_type": hpv_type,
                "candidate_id": f"{analysis_group}:OpenRDP:{method or 'method'}:{idx}",
                "parent_major_record_id": parent1,
                "parent_minor_record_id": parent2,
                "candidate_record_id": recombinant,
                "candidate_sample_id": candidate_meta.get("sample_id", recombinant),
                "candidate_sequence_role": candidate_role,
                "uncorrected_p": format_pvalue(pvalue),
                "used_hogan_siegmund": "",
                "log10_p": "" if pvalue in (None, 0.0) else f"{math.log10(pvalue):.6f}",
                "corrected_p": format_pvalue(pvalue),
                "corrected_p_mantissa": "",
                "min_segment_length": segment_length,
                "candidate_breakpoint_site": breakpoint_site,
                "candidate_breakpoints": candidate_breakpoints,
                "passes_pvalue_threshold": "yes" if passes_pvalue else "no",
                "passes_segment_length": "yes" if passes_segment else "no",
                "eligible_sample_candidate": "yes"
                if candidate_role == "sample" and passes_pvalue and passes_segment
                else "no",
                "evidence_method": method,
            }
        )

    candidates.sort(
        key=lambda row: (
            row["candidate_record_id"],
            float(row["corrected_p"]) if row["corrected_p"] else float("inf"),
            row["evidence_method"],
        )
    )
    return candidates


def main() -> int:
    args = parse_args()
    methods = [token for token in args.methods if token]
    replacements: dict[str, int] = {}
    alignment_path = Path(args.alignment)
    if args.sanitize_ambiguity_bases:
        alignment_path, replacements = sanitize_alignment_for_openrdp(alignment_path)
    cmd = [
        "openrdp",
        str(alignment_path),
        "--outfile",
        args.output_csv,
        "--methods",
        *methods,
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True, check=False)
    replacement_summary = (
        "Sanitized unsupported alignment characters to N: "
        + ", ".join(f"{base}={count}" for base, count in replacements.items())
        if replacements
        else "Sanitized unsupported alignment characters to N: none"
    )
    log_parts = [replacement_summary]
    if completed.stdout:
        log_parts.append(completed.stdout.rstrip())
    if completed.stderr:
        log_parts.append(completed.stderr.rstrip())
    log_text = "\n".join(log_parts) + "\n"
    Path(args.output_log).write_text(log_text, encoding="utf-8")

    manifest_rows = {row["normalized_record_id"]: row for row in read_tsv(Path(args.manifest_tsv))}
    raw_rows = parse_method_rows(Path(args.output_csv))
    candidates = build_candidates(
        raw_rows,
        manifest_rows,
        analysis_group=args.analysis_group,
        hpv_type=args.hpv_type,
        pvalue_threshold=args.pvalue_threshold,
        min_segment_length=args.min_segment_length,
    )

    sample_candidates = [row for row in candidates if row["candidate_sequence_role"] == "sample"]
    eligible_candidates = [row for row in sample_candidates if row["eligible_sample_candidate"] == "yes"]
    eligible_methods = sorted({row["evidence_method"] for row in eligible_candidates if row["evidence_method"]})

    write_tsv(
        Path(args.output_candidates_tsv),
        candidates,
        [
            "analysis_group",
            "hpv_type",
            "candidate_id",
            "parent_major_record_id",
            "parent_minor_record_id",
            "candidate_record_id",
            "candidate_sample_id",
            "candidate_sequence_role",
            "uncorrected_p",
            "used_hogan_siegmund",
            "log10_p",
            "corrected_p",
            "corrected_p_mantissa",
            "min_segment_length",
            "candidate_breakpoint_site",
            "candidate_breakpoints",
            "passes_pvalue_threshold",
            "passes_segment_length",
            "eligible_sample_candidate",
            "evidence_method",
        ],
    )

    write_json(
        Path(args.output_summary_json),
        {
            "analysis_group": args.analysis_group,
            "hpv_type": args.hpv_type,
            "command": cmd,
            "sanitized_alignment": str(alignment_path) if args.sanitize_ambiguity_bases else "",
            "sanitized_ambiguity_bases": args.sanitize_ambiguity_bases,
            "replaced_characters": replacements,
            "methods_requested": methods,
            "methods_with_eligible_candidates": eligible_methods,
            "exit_code": completed.returncode,
            "candidate_events": len(candidates),
            "sample_candidate_events": len(sample_candidates),
            "eligible_sample_candidates": len(eligible_candidates),
        },
    )
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
