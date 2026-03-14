#!/usr/bin/env python3
"""Build recombination summary tables and a human-readable markdown report."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--excluded-tsv", required=True)
    parser.add_argument("--gard-breakpoints-tsv", required=True)
    parser.add_argument("--gard-summary-json", required=True)
    parser.add_argument("--output-events-tsv", required=True)
    parser.add_argument("--output-events-csv", required=True)
    parser.add_argument("--output-events-json", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--output-multiqc-tsv", required=True)
    parser.add_argument("--gard-support-confidence", default="low")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def write_tsv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def build_events(breakpoints: list[int], confidence: str) -> list[dict[str, Any]]:
    if not breakpoints:
        return []

    unique_breakpoints = sorted(set(breakpoints))
    events: list[dict[str, Any]] = []
    for idx, bp in enumerate(unique_breakpoints, start=1):
        left_boundary = 1 if idx == 1 else unique_breakpoints[idx - 2] + 1
        right_boundary = unique_breakpoints[idx] if idx < len(unique_breakpoints) else "NA"
        events.append(
            {
                "event_id": f"GARD_{idx}",
                "breakpoint": bp,
                "segment_left_start": left_boundary,
                "segment_left_end": bp,
                "segment_right_start": bp + 1,
                "segment_right_end": right_boundary,
                "supporting_methods": "GARD",
                "confidence": confidence,
                "interpretation": "Putative recombination breakpoint inferred by phylogenetic incongruence.",
            }
        )
    return events


def build_markdown(
    manifest: list[dict[str, str]],
    excluded: list[dict[str, str]],
    events: list[dict[str, Any]],
    gard_summary: dict[str, Any],
) -> str:
    sample_ids = sorted({row.get("sample_id", "") for row in manifest if row.get("sample_id")})
    small_list = ", ".join(sample_ids[:10])
    if len(sample_ids) > 10:
        small_list += f", ... (+{len(sample_ids) - 10} more)"

    lines = [
        "# Recombination Analysis Summary",
        "",
        "## Overview",
        "This step performed recombination signal screening using MAFFT alignment and HyPhy GARD breakpoint inference.",
        "RDP-based confirmation is not part of this automated workflow.",
        "",
        "## Input selection",
        f"- Included sequence records: {len(manifest)}",
        f"- Included unique samples: {len(sample_ids)}",
        f"- Excluded rows: {len(excluded)}",
    ]
    if sample_ids:
        lines.append(f"- Sample IDs (truncated): {small_list}")

    lines.extend(
        [
            "",
            "## Breakpoint findings",
            f"- GARD status: {gard_summary.get('status', 'unknown')}",
            f"- Breakpoints detected: {gard_summary.get('n_breakpoints', 0)}",
            f"- Candidate events reported: {len(events)}",
            "",
            "## Interpretation note",
            "HPV recombination signals are generally rare. Putative breakpoints should be interpreted cautiously and validated",
            "against alternative explanations such as alignment artifacts, mixed infections, contamination, or low-depth consensus errors.",
            "",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    manifest = read_tsv(Path(args.manifest_tsv))
    excluded = read_tsv(Path(args.excluded_tsv))
    breakpoints_rows = read_tsv(Path(args.gard_breakpoints_tsv))
    gard_summary = read_json(Path(args.gard_summary_json))

    breakpoints: list[int] = []
    for row in breakpoints_rows:
        raw = row.get("breakpoint", "")
        try:
            breakpoints.append(int(raw))
        except (TypeError, ValueError):
            continue

    events = build_events(breakpoints, args.gard_support_confidence)
    warnings: list[dict[str, str]] = []

    if not events:
        warnings.append(
            {
                "warning_code": "no_recombination_events",
                "message": "No candidate breakpoints were detected by GARD.",
            }
        )
    if len(manifest) < 4:
        warnings.append(
            {
                "warning_code": "low_sequence_count",
                "message": "Fewer than 4 sequences were analyzed; breakpoint inference may be unstable.",
            }
        )

    event_fields = [
        "event_id",
        "breakpoint",
        "segment_left_start",
        "segment_left_end",
        "segment_right_start",
        "segment_right_end",
        "supporting_methods",
        "confidence",
        "interpretation",
    ]
    write_tsv(Path(args.output_events_tsv), events, event_fields)
    write_csv(Path(args.output_events_csv), events, event_fields)
    Path(args.output_events_json).write_text(json.dumps(events, indent=2) + "\n", encoding="utf-8")
    write_tsv(Path(args.output_warnings_tsv), warnings, ["warning_code", "message"])

    summary_md = build_markdown(manifest, excluded, events, gard_summary)
    Path(args.output_summary_md).write_text(summary_md + "\n", encoding="utf-8")

    excluded_controls = sum(1 for row in excluded if row.get("reason") in {"control_pattern", "exclude_list"})
    metrics = [
        {"metric": "included_records", "value": len(manifest)},
        {"metric": "excluded_rows", "value": len(excluded)},
        {"metric": "excluded_controls", "value": excluded_controls},
        {"metric": "gard_breakpoints", "value": len(set(breakpoints))},
        {"metric": "candidate_events", "value": len(events)},
        {"metric": "warnings", "value": len(warnings)},
        {"metric": "rdp_enabled", "value": "false"},
    ]
    write_tsv(Path(args.output_multiqc_tsv), metrics, ["metric", "value"])

    return 0


if __name__ == "__main__":
    sys.exit(main())
