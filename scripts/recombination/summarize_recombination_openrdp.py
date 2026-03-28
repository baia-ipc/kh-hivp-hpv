#!/usr/bin/env python3
"""Aggregate stage-07 OpenRDP outputs into report tables and a handoff TSV."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import read_json, read_tsv, write_tsv  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screen-groups-tsv", required=True)
    parser.add_argument("--openrdp-candidates", nargs="+", required=True)
    parser.add_argument("--openrdp-summaries", nargs="+", required=True)
    parser.add_argument("--openrdp-logs", nargs="+", required=True)
    parser.add_argument("--openrdp-csvs", nargs="+", required=True)
    parser.add_argument("--step-outdir", required=True)
    parser.add_argument("--output-type-overview-tsv", required=True)
    parser.add_argument("--output-candidate-samples-tsv", required=True)
    parser.add_argument("--output-method-failures-tsv", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--output-groups-tsv", required=True)
    return parser.parse_args()


def json_by_group(paths: list[str]) -> dict[str, dict[str, Any]]:
    payloads: dict[str, dict[str, Any]] = {}
    for path in paths:
        payload = read_json(Path(path))
        key = str(payload.get("analysis_group", "")).strip()
        if key:
            payloads[key] = payload
    return payloads


def rows_by_group(paths: list[str], key_field: str) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for path in paths:
        for row in read_tsv(Path(path)):
            key = row.get(key_field, "").strip()
            if not key:
                continue
            grouped.setdefault(key, []).append(row)
    return grouped


def build_markdown(
    screen_groups: list[dict[str, str]],
    summaries: dict[str, dict[str, Any]],
) -> str:
    lines = [
        "# Recombination OpenRDP Summary",
        "",
        "## Interpretation",
        "This stage runs OpenRDP candidate scanning only. It does not perform final recombinant confirmation.",
        "",
        "## Groups",
    ]
    for row in sorted(screen_groups, key=lambda item: item["analysis_group"]):
        analysis_group = row["analysis_group"]
        summary = summaries.get(analysis_group, {})
        lines.append(
            f"- {row['hpv_type']}: requested={','.join(summary.get('methods_requested', [])) or 'NA'}, "
            f"successful={','.join(summary.get('successful_methods', [])) or 'none'}, "
            f"failed={','.join(summary.get('failed_methods', [])) or 'none'}, "
            f"eligible_candidates={summary.get('eligible_sample_candidates', 0)}"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    step_outdir = Path(args.step_outdir).resolve()
    screen_groups = read_tsv(Path(args.screen_groups_tsv))
    candidates_by_group = rows_by_group(args.openrdp_candidates, "analysis_group")
    summaries = json_by_group(args.openrdp_summaries)

    overview_rows: list[dict[str, Any]] = []
    candidate_rows: list[dict[str, Any]] = []
    method_rows: list[dict[str, Any]] = []
    warning_rows: list[dict[str, Any]] = []
    handoff_rows: list[dict[str, Any]] = []

    for screen_row in sorted(screen_groups, key=lambda item: item["analysis_group"]):
        analysis_group = screen_row["analysis_group"]
        hpv_type = screen_row["hpv_type"]
        summary = summaries.get(analysis_group, {})
        published_candidates = step_outdir / "openrdp" / f"{analysis_group}.openrdp.candidates.tsv"
        published_summary = step_outdir / "openrdp" / f"{analysis_group}.openrdp.summary.json"
        published_log = step_outdir / "openrdp" / f"{analysis_group}.openrdp.log"
        published_csv = step_outdir / "openrdp" / f"{analysis_group}.openrdp.csv"

        overview_rows.append(
            {
                "type_compound_id": analysis_group,
                "hpv_type": hpv_type,
                "methods_requested": ",".join(summary.get("methods_requested", [])),
                "successful_methods": ",".join(summary.get("successful_methods", [])),
                "failed_methods": ",".join(summary.get("failed_methods", [])),
                "fallback_to_per_method": "yes" if summary.get("fallback_to_per_method") else "no",
                "combined_exit_code": summary.get("combined_exit_code", summary.get("exit_code", "")),
                "candidate_events": summary.get("candidate_events", 0),
                "sample_candidate_events": summary.get("sample_candidate_events", 0),
                "eligible_sample_candidates": summary.get("eligible_sample_candidates", 0),
            }
        )

        for candidate in candidates_by_group.get(analysis_group, []):
            if candidate.get("candidate_sequence_role") != "sample":
                continue
            candidate_rows.append(
                {
                    "candidate_compound_id": candidate.get("candidate_id", ""),
                    "hpv_type": hpv_type,
                    "sample_id": candidate.get("candidate_sample_id", ""),
                    "candidate_record_id": candidate.get("candidate_record_id", ""),
                    "parent_major_record_id": candidate.get("parent_major_record_id", ""),
                    "parent_minor_record_id": candidate.get("parent_minor_record_id", ""),
                    "corrected_p": candidate.get("corrected_p", ""),
                    "candidate_breakpoints": candidate.get("candidate_breakpoints", ""),
                    "eligible_sample_candidate": candidate.get("eligible_sample_candidate", ""),
                    "evidence_method": candidate.get("evidence_method", ""),
                }
            )

        requested = summary.get("methods_requested", [])
        successful = set(summary.get("successful_methods", []))
        failed = set(summary.get("failed_methods", []))
        eligible_methods = {str(method).lower() for method in summary.get("methods_with_eligible_candidates", [])}
        exit_codes = summary.get("per_method_exit_codes", {})
        for method in requested:
            status = "ok" if method in successful else "failed"
            method_rows.append(
                {
                    "method_compound_id": f"{analysis_group}:{method}",
                    "hpv_type": hpv_type,
                    "method": method,
                    "status": status,
                    "exit_code": exit_codes.get(method, ""),
                    "produced_eligible_candidate": "yes" if method.lower() in eligible_methods else "no",
                    "openrdp_log": str(published_log),
                }
            )
        for method in sorted(failed):
            warning_rows.append(
                {
                    "warning_compound_id": f"{analysis_group}:{method}",
                    "analysis_group": analysis_group,
                    "hpv_type": hpv_type,
                    "warning_code": "openrdp_method_failed",
                    "message": f"OpenRDP method {method} failed for {analysis_group}.",
                }
            )

        handoff = dict(screen_row)
        handoff.update(
            {
                "openrdp_candidates_tsv": str(published_candidates),
                "openrdp_summary_json": str(published_summary),
                "openrdp_log": str(published_log),
                "openrdp_csv": str(published_csv),
            }
        )
        handoff_rows.append(handoff)

    write_tsv(
        Path(args.output_type_overview_tsv),
        overview_rows,
        [
            "type_compound_id",
            "hpv_type",
            "methods_requested",
            "successful_methods",
            "failed_methods",
            "fallback_to_per_method",
            "combined_exit_code",
            "candidate_events",
            "sample_candidate_events",
            "eligible_sample_candidates",
        ],
    )
    write_tsv(
        Path(args.output_candidate_samples_tsv),
        candidate_rows,
        [
            "candidate_compound_id",
            "hpv_type",
            "sample_id",
            "candidate_record_id",
            "parent_major_record_id",
            "parent_minor_record_id",
            "corrected_p",
            "candidate_breakpoints",
            "eligible_sample_candidate",
            "evidence_method",
        ],
    )
    write_tsv(
        Path(args.output_method_failures_tsv),
        method_rows,
        [
            "method_compound_id",
            "hpv_type",
            "method",
            "status",
            "exit_code",
            "produced_eligible_candidate",
            "openrdp_log",
        ],
    )
    write_tsv(
        Path(args.output_warnings_tsv),
        warning_rows,
        ["warning_compound_id", "analysis_group", "hpv_type", "warning_code", "message"],
    )
    write_tsv(
        Path(args.output_groups_tsv),
        handoff_rows,
        [
            "analysis_group",
            "hpv_type",
            "alignment_fasta",
            "manifest_tsv",
            "duplicate_map_tsv",
            "representative_ids_tsv",
            "group_summary_json",
            "sample_count",
            "reference_count",
            "gard_json",
            "gard_breakpoints_tsv",
            "gard_summary_json",
            "gard_warnings_tsv",
            "gard_log",
            "pairwise_identity_tsv",
            "pairwise_identity_png",
            "plot_warnings_tsv",
            "openrdp_candidates_tsv",
            "openrdp_summary_json",
            "openrdp_log",
            "openrdp_csv",
        ],
    )
    Path(args.output_summary_md).write_text(build_markdown(screen_groups, summaries) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
