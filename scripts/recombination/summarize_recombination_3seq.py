#!/usr/bin/env python3
"""Aggregate stage-07 3SEQ outputs into report tables and a handoff TSV."""

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
    parser.add_argument("--candidates", nargs="+", required=True)
    parser.add_argument("--summaries", nargs="+", required=True)
    parser.add_argument("--logs", nargs="+", required=True)
    parser.add_argument("--recs", nargs="+", required=True)
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


def build_conclusion(summary: dict[str, Any]) -> str:
    if summary.get("successful_methods") and not summary.get("eligible_sample_candidates", 0):
        return "No eligible sample-level recombination candidates detected"
    if summary.get("eligible_sample_candidates", 0):
        return "Eligible sample-level recombination candidates detected"
    return "3SEQ scan did not complete cleanly"


def build_evidence(summary: dict[str, Any]) -> str:
    candidate_events = summary.get("candidate_events", 0)
    sample_events = summary.get("sample_candidate_events", 0)
    eligible = summary.get("eligible_sample_candidates", 0)
    exit_code = summary.get("scan_exit_code", summary.get("exit_code", "NA"))
    timed_out = "yes" if summary.get("scan_timed_out") else "no"
    if summary.get("successful_methods") and not eligible:
        return (
            f"3SEQ exited with code {exit_code}; timed_out={timed_out}; "
            f"total candidate triplets={candidate_events}; sample candidate triplets={sample_events}; "
            f"eligible sample candidates={eligible}."
        )
    if eligible:
        return (
            f"3SEQ exited with code {exit_code}; timed_out={timed_out}; "
            f"sample candidate triplets={sample_events}; eligible sample candidates={eligible}."
        )
    return f"3SEQ did not complete cleanly; exit_code={exit_code}; timed_out={timed_out}."


def build_markdown(screen_groups: list[dict[str, str]], summaries: dict[str, dict[str, Any]]) -> str:
    clean_negative_groups = []
    lines = [
        "# Recombination 3SEQ Summary",
        "",
        "## Interpretation",
        "This stage runs 3SEQ candidate scanning only. It does not perform final recombinant confirmation.",
        "A clean negative result means 3SEQ finished successfully and no eligible sample-level recombination candidates were detected.",
        "",
        "## Overall conclusion",
    ]
    for row in sorted(screen_groups, key=lambda item: item["analysis_group"]):
        analysis_group = row["analysis_group"]
        summary = summaries.get(analysis_group, {})
        if summary.get("successful_methods") and not summary.get("eligible_sample_candidates", 0):
            clean_negative_groups.append(row["hpv_type"])
    if clean_negative_groups:
        lines.append(f"- Clean negative result for: {', '.join(clean_negative_groups)}.")
    else:
        lines.append("- No stage-wide clean negative conclusion was available for every analyzed HPV group.")
    lines.extend([
        "",
        "## Groups",
    ])
    for row in sorted(screen_groups, key=lambda item: item["analysis_group"]):
        analysis_group = row["analysis_group"]
        summary = summaries.get(analysis_group, {})
        lines.append(f"- {row['hpv_type']}: {build_conclusion(summary)}. {build_evidence(summary)}")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    step_outdir = Path(args.step_outdir).resolve()
    screen_groups = read_tsv(Path(args.screen_groups_tsv))
    candidates_by_group = rows_by_group(args.candidates, "analysis_group")
    summaries = json_by_group(args.summaries)

    overview_rows: list[dict[str, Any]] = []
    candidate_rows: list[dict[str, Any]] = []
    method_rows: list[dict[str, Any]] = []
    warning_rows: list[dict[str, Any]] = []
    handoff_rows: list[dict[str, Any]] = []

    for screen_row in sorted(screen_groups, key=lambda item: item["analysis_group"]):
        analysis_group = screen_row["analysis_group"]
        hpv_type = screen_row["hpv_type"]
        summary = summaries.get(analysis_group, {})
        published_candidates = step_outdir / "3seq" / f"{analysis_group}.3seq.candidates.tsv"
        published_summary = step_outdir / "3seq" / f"{analysis_group}.3seq.summary.json"
        published_log = step_outdir / "3seq" / f"{analysis_group}.3seq.log"
        published_rec = step_outdir / "3seq" / f"{analysis_group}.3seq.rec"

        overview_rows.append(
            {
                "type_compound_id": analysis_group,
                "hpv_type": hpv_type,
                "conclusion": build_conclusion(summary),
                "evidence_summary": build_evidence(summary),
                "methods_requested": "3seq",
                "successful_methods": ",".join(summary.get("successful_methods", [])),
                "failed_methods": ",".join(summary.get("failed_methods", [])),
                "timed_out_methods": ",".join(summary.get("timed_out_methods", [])),
                "scan_exit_code": summary.get("scan_exit_code", summary.get("exit_code", "")),
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

        method_rows.append(
            {
                "method_compound_id": f"{analysis_group}:3seq",
                "hpv_type": hpv_type,
                "method": "3seq",
                "status": "ok" if summary.get("successful_methods") else "failed",
                "exit_code": summary.get("scan_exit_code", ""),
                "timed_out": "yes" if summary.get("scan_timed_out") else "no",
                "produced_eligible_candidate": "yes" if summary.get("eligible_sample_candidates", 0) else "no",
                "conclusion": build_conclusion(summary),
                "evidence_summary": build_evidence(summary),
                "scan_log": str(published_log),
            }
        )
        if summary.get("failed_methods"):
            warning_rows.append(
                {
                    "warning_compound_id": f"{analysis_group}:3seq",
                    "analysis_group": analysis_group,
                    "hpv_type": hpv_type,
                    "warning_code": "3seq_failed",
                    "message": f"3SEQ failed or timed out for {analysis_group}; downstream confirmation will use an empty candidate set.",
                }
            )

        handoff = dict(screen_row)
        handoff.update(
            {
                "openrdp_candidates_tsv": str(published_candidates),
                "openrdp_summary_json": str(published_summary),
                "openrdp_log": str(published_log),
                "openrdp_csv": str(published_rec),
            }
        )
        handoff_rows.append(handoff)

    write_tsv(
        Path(args.output_type_overview_tsv),
        overview_rows,
        [
            "type_compound_id",
            "hpv_type",
            "conclusion",
            "evidence_summary",
            "methods_requested",
            "successful_methods",
            "failed_methods",
            "timed_out_methods",
            "scan_exit_code",
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
            "timed_out",
            "produced_eligible_candidate",
            "conclusion",
            "evidence_summary",
            "scan_log",
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
