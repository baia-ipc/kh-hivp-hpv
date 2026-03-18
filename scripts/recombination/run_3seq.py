#!/usr/bin/env python3
"""Run 3SEQ on an aligned FASTA and parse sample-level candidates."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import read_tsv, write_json, write_tsv  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--three-seq-bin", required=True)
    parser.add_argument("--three-seq-table", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--pvalue-threshold", type=float, default=0.01)
    parser.add_argument("--min-segment-length", type=int, default=500)
    parser.add_argument("--output-candidates-tsv", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--output-log", required=True)
    parser.add_argument("--output-rec", required=True)
    return parser.parse_args()


def parse_breakpoints(columns: list[str]) -> tuple[int | None, str]:
    values: list[int] = []
    for token in columns:
        try:
            values.append(int(token))
        except ValueError:
            continue
    values = sorted(set(values))
    if not values:
        return None, ""
    pivot = values[len(values) // 2]
    return pivot, ",".join(str(value) for value in values)


def parse_rec_file(rec_path: Path, manifest_rows: dict[str, dict[str, str]], args: argparse.Namespace) -> list[dict[str, Any]]:
    if not rec_path.exists() or rec_path.stat().st_size == 0:
        return []

    candidates: list[dict[str, Any]] = []
    with rec_path.open("r", encoding="utf-8") as handle:
        for idx, raw_line in enumerate(handle, start=1):
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 12:
                continue
            parent_a, parent_b, child = parts[:3]
            child_meta = manifest_rows.get(child, {})
            child_role = child_meta.get("sequence_role", "unknown")
            corrected_p = float(parts[9])
            min_length = int(parts[11])
            breakpoint_site, breakpoint_list = parse_breakpoints(parts[12:])
            candidates.append(
                {
                    "analysis_group": args.analysis_group,
                    "hpv_type": args.hpv_type,
                    "candidate_id": f"{args.analysis_group}:3SEQ:{idx}",
                    "parent_major_record_id": parent_a,
                    "parent_minor_record_id": parent_b,
                    "candidate_record_id": child,
                    "candidate_sample_id": child_meta.get("sample_id", child),
                    "candidate_sequence_role": child_role,
                    "uncorrected_p": parts[6],
                    "used_hogan_siegmund": parts[7],
                    "log10_p": parts[8],
                    "corrected_p": f"{corrected_p:.12g}",
                    "corrected_p_mantissa": parts[10],
                    "min_segment_length": min_length,
                    "candidate_breakpoint_site": "" if breakpoint_site is None else breakpoint_site,
                    "candidate_breakpoints": breakpoint_list,
                    "passes_pvalue_threshold": "yes" if corrected_p <= args.pvalue_threshold else "no",
                    "passes_segment_length": "yes" if min_length >= args.min_segment_length else "no",
                    "eligible_sample_candidate": "yes"
                    if child_role == "sample" and corrected_p <= args.pvalue_threshold and min_length >= args.min_segment_length
                    else "no",
                }
            )
    return candidates


def main() -> int:
    args = parse_args()
    run_id = args.analysis_group
    prefix = f"{run_id}_3seq"
    work_rec = Path(f"{prefix}.3s.rec")
    work_log = Path(f"{prefix}.3s.log")

    cmd = [
        args.three_seq_bin,
        "-f",
        args.alignment,
        "-ptable",
        args.three_seq_table,
        "-d",
        f"-L{args.min_segment_length}",
        f"-t{args.pvalue_threshold}",
        "-id",
        prefix,
    ]

    completed = subprocess.run(cmd, capture_output=True, text=True, check=False)
    log_text = completed.stdout + ("\n" + completed.stderr if completed.stderr else "")
    Path(args.output_log).write_text(log_text, encoding="utf-8")

    if work_rec.exists():
        Path(args.output_rec).write_text(work_rec.read_text(encoding="utf-8"), encoding="utf-8")
    else:
        Path(args.output_rec).write_text("", encoding="utf-8")

    manifest_rows = {row["normalized_record_id"]: row for row in read_tsv(Path(args.manifest_tsv))}
    candidates = parse_rec_file(Path(args.output_rec), manifest_rows, args)
    sample_candidates = [row for row in candidates if row["candidate_sequence_role"] == "sample"]
    eligible_candidates = [row for row in sample_candidates if row["eligible_sample_candidate"] == "yes"]

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
        ],
    )

    write_json(
        Path(args.output_summary_json),
        {
            "analysis_group": args.analysis_group,
            "hpv_type": args.hpv_type,
            "command": cmd,
            "exit_code": completed.returncode,
            "candidate_triplets": len(candidates),
            "sample_candidate_triplets": len(sample_candidates),
            "eligible_sample_candidates": len(eligible_candidates),
        },
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
