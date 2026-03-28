#!/usr/bin/env python3
"""Run OpenRDP on an aligned FASTA and emit sample-level candidate tables."""

from __future__ import annotations

import argparse
import csv
import json
import math
import shlex
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OPENRDP_CSV_FIELDS = ["Method", "Start", "End", "Recombinant", "Parent1", "Parent2", "Pvalue"]


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


def write_openrdp_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OPENRDP_CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in OPENRDP_CSV_FIELDS})


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


def build_openrdp_cmd(alignment_path: Path, output_csv: Path, methods: list[str]) -> list[str]:
    return [
        "openrdp",
        str(alignment_path),
        "--outfile",
        str(output_csv),
        "--methods",
        *methods,
    ]


def run_openrdp_cmd(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def format_completed_run(label: str, cmd: list[str], completed: subprocess.CompletedProcess[str]) -> str:
    parts = [
        f"[{label}] command: {' '.join(shlex.quote(token) for token in cmd)}",
        f"[{label}] exit_code: {completed.returncode}",
    ]
    if completed.stdout:
        parts.append(f"[{label}] stdout:\n{completed.stdout.rstrip()}")
    if completed.stderr:
        parts.append(f"[{label}] stderr:\n{completed.stderr.rstrip()}")
    return "\n".join(parts)


def main() -> int:
    args = parse_args()
    methods = [token for token in args.methods if token]
    replacements: dict[str, int] = {}
    alignment_path = Path(args.alignment)
    output_csv_path = Path(args.output_csv)
    if args.sanitize_ambiguity_bases:
        alignment_path, replacements = sanitize_alignment_for_openrdp(alignment_path)
    replacement_summary = (
        "Sanitized unsupported alignment characters to N: "
        + ", ".join(f"{base}={count}" for base, count in replacements.items())
        if replacements
        else "Sanitized unsupported alignment characters to N: none"
    )
    log_parts = [replacement_summary]

    cmd = build_openrdp_cmd(alignment_path, output_csv_path, methods)
    try:
        completed = run_openrdp_cmd(cmd)
    except FileNotFoundError as exc:
        log_parts.append(f"[combined] command failed before execution: {exc}")
        Path(args.output_log).write_text("\n".join(log_parts) + "\n", encoding="utf-8")
        raise

    log_parts.append(format_completed_run("combined", cmd, completed))
    fallback_used = completed.returncode != 0
    method_exit_codes: dict[str, int] = {}
    failed_methods: list[str] = []
    successful_methods: list[str] = []

    if fallback_used:
        log_parts.append("Combined OpenRDP run failed; retrying methods individually.")
        raw_rows: list[dict[str, str]] = []
        for method in methods:
            method_csv = output_csv_path.parent / f"openrdp_method_{method}.csv"
            method_cmd = build_openrdp_cmd(alignment_path, method_csv, [method])
            method_completed = run_openrdp_cmd(method_cmd)
            method_exit_codes[method] = method_completed.returncode
            log_parts.append(format_completed_run(f"method:{method}", method_cmd, method_completed))
            if method_completed.returncode == 0:
                successful_methods.append(method)
                raw_rows.extend(parse_method_rows(method_csv))
            else:
                failed_methods.append(method)
            method_csv.unlink(missing_ok=True)
    else:
        raw_rows = parse_method_rows(output_csv_path)
        successful_methods = list(methods)
        for method in methods:
            method_exit_codes[method] = 0

    write_openrdp_csv(output_csv_path, raw_rows)
    Path(args.output_log).write_text("\n".join(log_parts) + "\n", encoding="utf-8")

    manifest_rows = {row["normalized_record_id"]: row for row in read_tsv(Path(args.manifest_tsv))}
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
            "fallback_to_per_method": fallback_used,
            "successful_methods": successful_methods,
            "failed_methods": failed_methods,
            "methods_with_eligible_candidates": eligible_methods,
            "combined_exit_code": completed.returncode,
            "per_method_exit_codes": method_exit_codes,
            "exit_code": 0 if fallback_used else completed.returncode,
            "candidate_events": len(candidates),
            "sample_candidate_events": len(sample_candidates),
            "eligible_sample_candidates": len(eligible_candidates),
        },
    )
    return 0 if fallback_used else completed.returncode


if __name__ == "__main__":
    sys.exit(main())
