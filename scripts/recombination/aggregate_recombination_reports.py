#!/usr/bin/env python3
"""Combine per-type recombination summaries into final step outputs."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import read_tsv, write_tsv  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--type-overview", nargs="+", required=True)
    parser.add_argument("--candidate-samples", nargs="+", required=True)
    parser.add_argument("--breakpoint-support", nargs="+", required=True)
    parser.add_argument("--duplicate-map", nargs="+", required=True)
    parser.add_argument("--summary-md", nargs="+", required=True)
    parser.add_argument("--events-tsv", nargs="+", required=True)
    parser.add_argument("--warnings-tsv", nargs="+", required=True)
    parser.add_argument("--output-type-overview", required=True)
    parser.add_argument("--output-candidate-samples", required=True)
    parser.add_argument("--output-breakpoint-support", required=True)
    parser.add_argument("--output-duplicate-map", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-events-tsv", required=True)
    parser.add_argument("--output-events-csv", required=True)
    parser.add_argument("--output-events-json", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    return parser.parse_args()


def concat_tables(paths: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in paths:
        rows.extend(read_tsv(Path(path)))
    return rows


def main() -> int:
    args = parse_args()

    overview_rows = concat_tables(args.type_overview)
    candidate_rows = concat_tables(args.candidate_samples)
    breakpoint_rows = concat_tables(args.breakpoint_support)
    duplicate_rows = concat_tables(args.duplicate_map)
    event_rows = concat_tables(args.events_tsv)
    warning_rows = concat_tables(args.warnings_tsv)

    overview_rows.sort(key=lambda row: row.get("hpv_type", ""))
    candidate_rows.sort(key=lambda row: (row.get("hpv_type", ""), row.get("sample_id", "")))
    breakpoint_rows.sort(key=lambda row: (row.get("hpv_type", ""), row.get("breakpoint_site", "")))
    duplicate_rows.sort(key=lambda row: (row.get("hpv_type", ""), row.get("collapsed_into", "")))

    write_tsv(Path(args.output_type_overview), overview_rows, list(overview_rows[0].keys()) if overview_rows else ["type_compound_id"])
    write_tsv(
        Path(args.output_candidate_samples),
        candidate_rows,
        list(candidate_rows[0].keys()) if candidate_rows else ["sample_compound_id"],
    )
    write_tsv(
        Path(args.output_breakpoint_support),
        breakpoint_rows,
        list(breakpoint_rows[0].keys()) if breakpoint_rows else ["type_compound_id"],
    )
    write_tsv(
        Path(args.output_duplicate_map),
        duplicate_rows,
        list(duplicate_rows[0].keys()) if duplicate_rows else ["collapsed_into"],
    )
    write_tsv(
        Path(args.output_events_tsv),
        event_rows,
        list(event_rows[0].keys()) if event_rows else ["event_id"],
    )
    write_tsv(
        Path(args.output_warnings_tsv),
        warning_rows,
        list(warning_rows[0].keys()) if warning_rows else ["warning_code", "message"],
    )

    with Path(args.output_events_csv).open("w", encoding="utf-8", newline="") as handle:
        import csv

        fieldnames = list(event_rows[0].keys()) if event_rows else ["event_id"]
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in event_rows:
            writer.writerow(row)

    Path(args.output_events_json).write_text(__import__("json").dumps(event_rows, indent=2) + "\n", encoding="utf-8")

    summary_text_parts = []
    for path in args.summary_md:
        text = Path(path).read_text(encoding="utf-8").strip()
        if text:
            summary_text_parts.append(text)
    Path(args.output_summary_md).write_text("\n\n".join(summary_text_parts) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
