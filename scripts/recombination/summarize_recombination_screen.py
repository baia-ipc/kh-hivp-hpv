#!/usr/bin/env python3
"""Aggregate stage-06 recombination screening outputs into report tables."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import (  # noqa: E402
    classify_global_strength,
    parse_float,
    read_json,
    read_tsv,
    write_tsv,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--groups-tsv", required=True)
    parser.add_argument("--input-summary-json", required=True)
    parser.add_argument("--duplicate-map-tsv", required=True)
    parser.add_argument("--excluded-samples-tsv", required=True)
    parser.add_argument("--gard-breakpoints", nargs="+", required=True)
    parser.add_argument("--gard-summaries", nargs="+", required=True)
    parser.add_argument("--gard-warnings", nargs="+", required=True)
    parser.add_argument("--step-outdir", required=True)
    parser.add_argument("--similarity-plot-enabled", action="store_true")
    parser.add_argument("--output-type-overview-tsv", required=True)
    parser.add_argument("--output-input-groups-tsv", required=True)
    parser.add_argument("--output-breakpoint-support-tsv", required=True)
    parser.add_argument("--output-similarity-plots-tsv", required=True)
    parser.add_argument("--output-duplicate-map-tsv", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--output-groups-tsv", required=True)
    return parser.parse_args()


def rows_by_group(paths: list[str], key_field: str) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for path in paths:
        for row in read_tsv(Path(path)):
            key = row.get(key_field, "").strip()
            if not key:
                continue
            grouped.setdefault(key, []).append(row)
    return grouped


def json_by_group(paths: list[str]) -> dict[str, dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    for path in paths:
        payload = read_json(Path(path))
        key = str(payload.get("analysis_group", "")).strip()
        if key:
            grouped[key] = payload
    return grouped


def build_markdown(
    groups: list[dict[str, str]],
    summaries: dict[str, dict[str, Any]],
    input_summary: dict[str, Any],
) -> str:
    lines = [
        "# Recombination Screening Summary",
        "",
        "## Scope",
        f"- HPV groups screened: {len(groups)}",
        f"- Included sequence records: {input_summary.get('included_records', 'NA')}",
        f"- Excluded sample FASTA rows: {input_summary.get('excluded_rows', 'NA')}",
        "",
        "## Interpretation",
        "This stage performs input preparation, exact-sequence collapsing, alignment, optional pairwise identity plots, and GARD breakpoint screening only.",
        "No sample-level recombinant call is made at this stage.",
        "",
        "## Groups",
    ]
    for row in sorted(groups, key=lambda item: item["analysis_group"]):
        summary = summaries.get(row["analysis_group"], {})
        delta = parse_float(summary.get("delta_aicc_vs_no_breakpoint"))
        strength = classify_global_strength(delta)
        lines.append(
            f"- {row['hpv_type']}: samples={row['sample_count']}, background={row['reference_count']}, "
            f"breakpoints={summary.get('n_breakpoints', 0)}, delta_aicc={summary.get('delta_aicc_vs_no_breakpoint', 'NA')}, "
            f"strength={strength}"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    step_outdir = Path(args.step_outdir).resolve()
    groups = read_tsv(Path(args.groups_tsv))
    input_summary = read_json(Path(args.input_summary_json))
    duplicate_rows = read_tsv(Path(args.duplicate_map_tsv))
    excluded_rows = read_tsv(Path(args.excluded_samples_tsv))
    breakpoint_rows = rows_by_group(args.gard_breakpoints, "analysis_group")
    gard_summaries = json_by_group(args.gard_summaries)
    gard_warning_rows = rows_by_group(args.gard_warnings, "analysis_group")

    overview_rows: list[dict[str, Any]] = []
    input_rows: list[dict[str, Any]] = []
    similarity_rows: list[dict[str, Any]] = []
    output_breakpoint_rows: list[dict[str, Any]] = []
    output_warning_rows: list[dict[str, Any]] = []
    handoff_rows: list[dict[str, Any]] = []

    for group in sorted(groups, key=lambda item: item["analysis_group"]):
        analysis_group = group["analysis_group"]
        hpv_type = group["hpv_type"]
        group_summary = read_json(Path(group["summary_json"]))
        gard_summary = gard_summaries.get(analysis_group, {})
        delta_aicc = parse_float(gard_summary.get("delta_aicc_vs_no_breakpoint"))
        strength = classify_global_strength(delta_aicc)
        group_dir = step_outdir / "summary" / "groups" / analysis_group
        plot_tsv = step_outdir / "plots" / f"{analysis_group}.pairwise_identity.tsv"
        plot_png = step_outdir / "plots" / f"{analysis_group}.pairwise_identity.png"
        plot_warnings = step_outdir / "plots" / f"{analysis_group}.plot.warnings.tsv"

        overview_rows.append(
            {
                "type_compound_id": analysis_group,
                "hpv_type": hpv_type,
                "sample_sequences": group["sample_count"],
                "background_references": group["reference_count"],
                "collapsed_sequences": group.get("collapsed_sequence_count", ""),
                "duplicate_sequences": group_summary.get("duplicate_count", ""),
                "gard_status": gard_summary.get("status", "missing"),
                "gard_breakpoints": gard_summary.get("n_breakpoints", 0),
                "gard_delta_aicc": gard_summary.get("delta_aicc_vs_no_breakpoint", ""),
                "gard_signal_strength": strength,
            }
        )
        input_rows.append(
            {
                "type_compound_id": analysis_group,
                "hpv_type": hpv_type,
                "sample_sequences": group["sample_count"],
                "background_references": group["reference_count"],
                "collapsed_sequences": group.get("collapsed_sequence_count", ""),
                "manifest_tsv": str(group_dir / "manifest.tsv"),
                "representative_ids_tsv": str(group_dir / "representative_ids.tsv"),
                "alignment_fasta": str(step_outdir / "alignment" / f"{analysis_group}.full.aln.fasta"),
            }
        )
        similarity_rows.append(
            {
                "type_compound_id": analysis_group,
                "hpv_type": hpv_type,
                "plot_enabled": "yes" if args.similarity_plot_enabled else "no",
                "pairwise_identity_tsv": str(plot_tsv) if args.similarity_plot_enabled else "",
                "pairwise_identity_png": str(plot_png) if args.similarity_plot_enabled else "",
                "plot_warnings_tsv": str(plot_warnings) if args.similarity_plot_enabled else "",
            }
        )
        for row in breakpoint_rows.get(analysis_group, []):
            output_breakpoint_rows.append(
                {
                    "breakpoint_compound_id": f"{analysis_group}:{row['breakpoint_id']}",
                    "hpv_type": hpv_type,
                    "breakpoint_id": row["breakpoint_id"],
                    "breakpoint_site": row["breakpoint_site"],
                    "left_interval": f"{row['left_segment_start']}-{row['left_segment_end']}",
                    "right_interval": f"{row['right_segment_start']}-{row['right_segment_end']}",
                    "site_support": row.get("site_support", ""),
                    "support_strength": row.get("support_strength", ""),
                    "delta_aicc_vs_no_breakpoint": row.get("delta_aicc_vs_no_breakpoint", ""),
                }
            )
        for row in gard_warning_rows.get(analysis_group, []):
            output_warning_rows.append(
                {
                    "warning_compound_id": f"{analysis_group}:{row.get('warning_code', 'warning')}",
                    "analysis_group": analysis_group,
                    "hpv_type": hpv_type,
                    "warning_code": row.get("warning_code", ""),
                    "message": row.get("message", ""),
                }
            )
        handoff_rows.append(
            {
                "analysis_group": analysis_group,
                "hpv_type": hpv_type,
                "alignment_fasta": str(step_outdir / "alignment" / f"{analysis_group}.full.aln.fasta"),
                "manifest_tsv": str(group_dir / "manifest.tsv"),
                "duplicate_map_tsv": str(group_dir / "duplicate_map.tsv"),
                "representative_ids_tsv": str(group_dir / "representative_ids.tsv"),
                "group_summary_json": str(group_dir / "group_summary.json"),
                "sample_count": group["sample_count"],
                "reference_count": group["reference_count"],
                "gard_json": str(step_outdir / "gard" / f"{analysis_group}.gard.json"),
                "gard_breakpoints_tsv": str(step_outdir / "gard" / f"{analysis_group}.gard.breakpoints.tsv"),
                "gard_summary_json": str(step_outdir / "gard" / f"{analysis_group}.gard.summary.json"),
                "gard_warnings_tsv": str(step_outdir / "gard" / f"{analysis_group}.gard.warnings.tsv"),
                "gard_log": str(step_outdir / "gard" / f"{analysis_group}.gard.log"),
                "pairwise_identity_tsv": str(plot_tsv) if args.similarity_plot_enabled else "",
                "pairwise_identity_png": str(plot_png) if args.similarity_plot_enabled else "",
                "plot_warnings_tsv": str(plot_warnings) if args.similarity_plot_enabled else "",
            }
        )

    for row in excluded_rows:
        output_warning_rows.append(
            {
                "warning_compound_id": f"excluded:{row.get('sample_id') or row.get('run_id') or 'row'}",
                "analysis_group": "excluded",
                "hpv_type": row.get("hpv_type", ""),
                "warning_code": row.get("reason", "excluded"),
                "message": f"Excluded {row.get('run_id', '')}:{row.get('sample_id', '')} ({row.get('reason', '')})",
            }
        )

    duplicate_table_rows = []
    for idx, row in enumerate(duplicate_rows, start=1):
        duplicate_table_rows.append(
            {
                "duplicate_compound_id": f"{row.get('analysis_group', 'group')}:{idx}",
                "analysis_group": row.get("analysis_group", ""),
                "hpv_type": row.get("hpv_type", ""),
                "collapsed_into": row.get("collapsed_into", ""),
                "duplicate_record_id": row.get("duplicate_record_id", ""),
                "sequence_role": row.get("sequence_role", ""),
                "background_source": row.get("background_source", ""),
                "display_name": row.get("display_name", ""),
                "reason": row.get("reason", ""),
            }
        )

    write_tsv(
        Path(args.output_type_overview_tsv),
        overview_rows,
        [
            "type_compound_id",
            "hpv_type",
            "sample_sequences",
            "background_references",
            "collapsed_sequences",
            "duplicate_sequences",
            "gard_status",
            "gard_breakpoints",
            "gard_delta_aicc",
            "gard_signal_strength",
        ],
    )
    write_tsv(
        Path(args.output_input_groups_tsv),
        input_rows,
        [
            "type_compound_id",
            "hpv_type",
            "sample_sequences",
            "background_references",
            "collapsed_sequences",
            "manifest_tsv",
            "representative_ids_tsv",
            "alignment_fasta",
        ],
    )
    write_tsv(
        Path(args.output_breakpoint_support_tsv),
        output_breakpoint_rows,
        [
            "breakpoint_compound_id",
            "hpv_type",
            "breakpoint_id",
            "breakpoint_site",
            "left_interval",
            "right_interval",
            "site_support",
            "support_strength",
            "delta_aicc_vs_no_breakpoint",
        ],
    )
    write_tsv(
        Path(args.output_similarity_plots_tsv),
        similarity_rows,
        [
            "type_compound_id",
            "hpv_type",
            "plot_enabled",
            "pairwise_identity_tsv",
            "pairwise_identity_png",
            "plot_warnings_tsv",
        ],
    )
    write_tsv(
        Path(args.output_duplicate_map_tsv),
        duplicate_table_rows,
        [
            "duplicate_compound_id",
            "analysis_group",
            "hpv_type",
            "collapsed_into",
            "duplicate_record_id",
            "sequence_role",
            "background_source",
            "display_name",
            "reason",
        ],
    )
    write_tsv(
        Path(args.output_warnings_tsv),
        output_warning_rows,
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
        ],
    )
    Path(args.output_summary_md).write_text(
        build_markdown(groups, gard_summaries, input_summary) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
