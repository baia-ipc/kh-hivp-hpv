#!/usr/bin/env python3
"""Run GENECONV on an aligned FASTA and emit sample-level candidate tables."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import math
import shlex
import shutil
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

GENECONV_TIMEOUT_EXIT_CODE = 124


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False
    timeout_seconds: int | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--pvalue-threshold", type=float, default=0.01)
    parser.add_argument("--min-segment-length", type=int, default=500)
    parser.add_argument("--timeout-seconds", type=int, default=0)
    parser.add_argument("--sanitize-ambiguity-bases", action="store_true")
    parser.add_argument("--output-candidates-tsv", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--output-log", required=True)
    parser.add_argument("--output-frags", required=True)
    return parser.parse_args()


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


def sanitize_alignment_for_geneconv(input_path: Path) -> tuple[Path, dict[str, int]]:
    allowed = set("ATGCN-")
    replacements: Counter[str] = Counter()
    output_path = input_path.with_suffix(input_path.suffix + ".geneconv.fa")

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


def _coerce_output(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def run_cmd(cmd: list[str], timeout_seconds: int = 0) -> CommandResult:
    try:
        completed = subprocess.run(
            cmd,
            capture_output=True,
            text=False,
            check=False,
            timeout=timeout_seconds if timeout_seconds and timeout_seconds > 0 else None,
        )
        return CommandResult(
            completed.returncode,
            _coerce_output(completed.stdout),
            _coerce_output(completed.stderr),
        )
    except subprocess.TimeoutExpired as exc:
        return CommandResult(
            returncode=GENECONV_TIMEOUT_EXIT_CODE,
            stdout=_coerce_output(exc.stdout),
            stderr=_coerce_output(exc.stderr),
            timed_out=True,
            timeout_seconds=timeout_seconds,
        )


def format_completed_run(label: str, cmd: list[str], completed: CommandResult) -> str:
    parts = [
        f"[{label}] command: {' '.join(shlex.quote(token) for token in cmd)}",
        f"[{label}] exit_code: {completed.returncode}",
    ]
    if completed.timed_out:
        parts.append(f"[{label}] timed_out: yes")
        if completed.timeout_seconds:
            parts.append(f"[{label}] timeout_seconds: {completed.timeout_seconds}")
    if completed.stdout:
        parts.append(f"[{label}] stdout:\n{completed.stdout.rstrip()}")
    if completed.stderr:
        parts.append(f"[{label}] stderr:\n{completed.stderr.rstrip()}")
    return "\n".join(parts)


def openrdp_package_dir() -> Path:
    spec = importlib.util.find_spec("openrdp")
    if spec is None or spec.origin is None:
        raise RuntimeError("openrdp package not available in current environment")
    return Path(spec.origin).resolve().parent


def parse_geneconv_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if not path.exists() or path.stat().st_size == 0:
        return rows
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            if raw_line.startswith("#"):
                continue
            parts = raw_line.strip().split()
            if len(parts) < 6:
                continue
            parts[2:] = [item for item in parts[2:] if all(char.isalnum() or char == "." for char in item)]
            sequences = parts[1].split(";")
            recombinant = sequences[0]
            if len(sequences) == 2:
                parent1 = sequences[1]
                parent2 = "-"
            else:
                parent1 = "-"
                parent2 = "-"
            try:
                start = int(parts[4])
                end = int(parts[5])
            except ValueError:
                continue
            rows.append(
                {
                    "Parent1": parent1,
                    "Parent2": parent2,
                    "Recombinant": recombinant,
                    "uncorrected_p": "",
                    "used_hogan_siegmund": "",
                    "log10_p": "",
                    "corrected_p": parts[3],
                    "corrected_p_mantissa": "",
                    "min_segment_length": str(max(0, end - start + 1)),
                    "candidate_breakpoints": f"{start},{end}",
                }
            )
    return rows


def parse_float(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


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
        candidate_meta = manifest_rows.get(recombinant, {})
        candidate_role = candidate_meta.get("sequence_role", "unknown")
        corrected_p = parse_float(row.get("corrected_p", ""))
        segment_length = int(row.get("min_segment_length", "0") or 0)
        breakpoints = [token.strip() for token in row.get("candidate_breakpoints", "").split(",") if token.strip()]
        numeric_breakpoints = []
        for token in breakpoints:
            try:
                numeric_breakpoints.append(int(token))
            except ValueError:
                continue
        breakpoint_site = ""
        if len(numeric_breakpoints) >= 2:
            breakpoint_site = math.floor((numeric_breakpoints[0] + numeric_breakpoints[-1]) / 2)
        elif len(numeric_breakpoints) == 1:
            breakpoint_site = numeric_breakpoints[0]
        passes_pvalue = corrected_p is not None and corrected_p <= pvalue_threshold
        passes_segment = segment_length >= min_segment_length
        candidates.append(
            {
                "analysis_group": analysis_group,
                "hpv_type": hpv_type,
                "candidate_id": f"{analysis_group}:GENECONV:{idx}",
                "parent_major_record_id": parent1,
                "parent_minor_record_id": parent2,
                "candidate_record_id": recombinant,
                "candidate_sample_id": candidate_meta.get("sample_id", recombinant),
                "candidate_sequence_role": candidate_role,
                "uncorrected_p": row.get("uncorrected_p", ""),
                "used_hogan_siegmund": row.get("used_hogan_siegmund", ""),
                "log10_p": row.get("log10_p", ""),
                "corrected_p": row.get("corrected_p", ""),
                "corrected_p_mantissa": row.get("corrected_p_mantissa", ""),
                "min_segment_length": segment_length,
                "candidate_breakpoint_site": breakpoint_site,
                "candidate_breakpoints": ",".join(str(value) for value in numeric_breakpoints),
                "passes_pvalue_threshold": "yes" if passes_pvalue else "no",
                "passes_segment_length": "yes" if passes_segment else "no",
                "eligible_sample_candidate": "yes"
                if candidate_role == "sample" and passes_pvalue and passes_segment
                else "no",
                "evidence_method": "GENECONV",
            }
        )
    candidates.sort(
        key=lambda row: (
            row["candidate_record_id"],
            float(row["corrected_p"]) if row["corrected_p"] else float("inf"),
        )
    )
    return candidates


def copy_or_empty(source: Path | None, destination: Path) -> None:
    if source and source.exists():
        shutil.copyfile(source, destination)
    else:
        destination.write_text("", encoding="utf-8")


def main() -> int:
    args = parse_args()
    replacements: dict[str, int] = {}
    alignment_path = Path(args.alignment)
    if args.sanitize_ambiguity_bases:
        alignment_path, replacements = sanitize_alignment_for_geneconv(alignment_path)

    output_candidates = Path(args.output_candidates_tsv)
    output_summary = Path(args.output_summary_json)
    output_log = Path(args.output_log)
    output_frags = Path(args.output_frags)

    replacement_summary = (
        "Sanitized unsupported alignment characters to N: "
        + ", ".join(f"{base}={count}" for base, count in replacements.items())
        if replacements
        else "Sanitized unsupported alignment characters to N: none"
    )
    log_parts = [replacement_summary]

    package_dir = openrdp_package_dir()
    bin_name = "geneconv.Unix"
    if sys.platform.startswith("win"):
        bin_name = "windows_geneconv.exe"
    elif sys.platform == "darwin":
        bin_name = "geneconv.macOS"
    binary_path = package_dir / "bin" / "GENECONV" / bin_name

    cfg_path = Path("geneconv.cfg").resolve()
    cfg_path.write_text(
        "\n".join(
            [
                "#GCONV_CONFIG",
                f"  -inputpath={alignment_path.resolve()}",
                "  -Gscale=1",
                "  -Minlength=1",
                "  -Minnpoly=2",
                "  -Minscore=2",
                "  -Maxoverlap=1",
                "",
            ]
        ),
        encoding="utf-8",
    )

    cmd = [
        str(binary_path),
        f"-Seqfile={alignment_path}",
        f"-Config={cfg_path}",
        "-nolog",
    ]
    completed = run_cmd(cmd, args.timeout_seconds)
    log_parts.append(format_completed_run("scan", cmd, completed))

    raw_frags = alignment_path.with_suffix("").with_suffix(".frags")
    if not raw_frags.exists():
        raw_frags = Path(alignment_path.stem + ".frags")
    copy_or_empty(raw_frags if raw_frags.exists() else None, output_frags)
    cfg_path.unlink(missing_ok=True)

    raw_rows = parse_geneconv_rows(output_frags) if completed.returncode == 0 else []
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

    write_tsv(
        output_candidates,
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
        output_summary,
        {
            "analysis_group": args.analysis_group,
            "hpv_type": args.hpv_type,
            "candidate_source": "GENECONV",
            "command": cmd,
            "sanitized_alignment": str(alignment_path) if args.sanitize_ambiguity_bases else "",
            "sanitized_ambiguity_bases": args.sanitize_ambiguity_bases,
            "replaced_characters": replacements,
            "methods_requested": ["geneconv"],
            "successful_methods": ["geneconv"] if completed.returncode == 0 else [],
            "failed_methods": [] if completed.returncode == 0 else ["geneconv"],
            "timed_out_methods": ["geneconv"] if completed.timed_out else [],
            "methods_with_eligible_candidates": ["geneconv"] if eligible_candidates else [],
            "scan_timed_out": completed.timed_out,
            "scan_exit_code": completed.returncode,
            "exit_code": 0,
            "candidate_events": len(candidates),
            "sample_candidate_events": len(sample_candidates),
            "eligible_sample_candidates": len(eligible_candidates),
        },
    )
    output_log.write_text("\n".join(log_parts) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
