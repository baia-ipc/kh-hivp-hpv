#!/usr/bin/env python3
"""Aggregate HPV-focused recombination outputs into report tables."""

from __future__ import annotations

import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

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
    parser.add_argument("--manifest-tsv", required=True)
    parser.add_argument("--duplicate-map-tsv", required=True)
    parser.add_argument("--gard-json", required=True)
    parser.add_argument("--gard-breakpoints-tsv", required=True)
    parser.add_argument("--gard-summary-json", required=True)
    parser.add_argument("--three-seq-candidates-tsv", required=True)
    parser.add_argument("--three-seq-summary-json", required=True)
    parser.add_argument("--tree-confirmation-tsv", required=True)
    parser.add_argument("--read-validation-tsv", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--samples-vs-lineage-sets-tsv", required=True)
    parser.add_argument("--samples-vs-database-tsv", required=True)
    parser.add_argument("--output-events-tsv", required=True)
    parser.add_argument("--output-events-csv", required=True)
    parser.add_argument("--output-events-json", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--output-type-overview-tsv", required=True)
    parser.add_argument("--output-candidate-samples-tsv", required=True)
    parser.add_argument("--output-breakpoint-support-tsv", required=True)
    parser.add_argument("--output-duplicate-map-tsv", required=True)
    parser.add_argument("--gard-support-confidence", default="low")
    return parser.parse_args()


def invert_duplicate_map(manifest_rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    mapping: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in manifest_rows:
        mapping[row["collapsed_into"]].append(row)
    return mapping


def load_nearest_lineages(path: Path, hpv_type: str) -> dict[str, dict[str, str]]:
    best: dict[str, dict[str, str]] = {}
    for row in read_tsv(path):
        sample = row.get("sample")
        lineage = row.get("lineage", "")
        if not sample or not lineage:
            continue
        if hpv_type == "HPV16" and not lineage.startswith(("A", "B", "C", "D")):
            continue
        score = parse_float(row.get("jaccard")) or 0.0
        if sample not in best or score > (parse_float(best[sample].get("jaccard")) or -1.0):
            best[sample] = {"lineage": lineage, "jaccard": row.get("jaccard", "")}
    return best


def load_nearest_database_ids(path: Path) -> dict[str, str]:
    sample_hits: dict[str, Counter[str]] = defaultdict(Counter)
    for row in read_tsv(path):
        sample = row.get("sample")
        db_ids = [token.strip() for token in (row.get("database_ids") or "").split(",") if token.strip()]
        if not sample:
            continue
        for db_id in db_ids:
            sample_hits[sample][db_id] += 1
    best: dict[str, str] = {}
    for sample, counts in sample_hits.items():
        if not counts:
            continue
        ordered = counts.most_common(3)
        best[sample] = ",".join(db_id for db_id, _ in ordered)
    return best


def determine_candidate_record(
    sample_row: dict[str, str],
    representative_candidates: dict[str, dict[str, str]],
    duplicate_groups: dict[str, list[dict[str, str]]],
) -> dict[str, str] | None:
    collapsed_into = sample_row["collapsed_into"]
    if collapsed_into in representative_candidates:
        return representative_candidates[collapsed_into]
    for member in duplicate_groups.get(collapsed_into, []):
        if member["normalized_record_id"] in representative_candidates:
            return representative_candidates[member["normalized_record_id"]]
    return None


def build_markdown(
    hpv_type: str,
    overview_row: dict[str, Any],
    candidate_rows: list[dict[str, Any]],
    breakpoint_rows: list[dict[str, Any]],
) -> str:
    candidate_calls = [row for row in candidate_rows if row["final_status"] == "candidate_recombinant"]
    inconclusive = [row for row in candidate_rows if row["final_status"] == "inconclusive"]
    lines = [
        f"# Recombination Confirmation Summary: {hpv_type}",
        "",
        "## Interpretation",
        f"- Background mode: tree-selected same-type references",
        f"- Sample sequences analyzed: {overview_row['sample_sequences']}",
        f"- Background references analyzed: {overview_row['background_references']}",
        f"- GARD breakpoints detected: {overview_row['gard_breakpoints']}",
        f"- GARD delta c-AIC versus no-breakpoint: {overview_row['gard_delta_aicc']}",
        f"- 3SEQ eligible sample candidates: {overview_row['three_seq_eligible_candidates']}",
        f"- Final candidate recombinant samples: {len(candidate_calls)}",
        "",
        "## Note",
        "GARD remains an alignment-level screen in this workflow.",
        "A sample is only reported as `candidate_recombinant` when GARD, 3SEQ, IQ-TREE window switching, and read validation all agree.",
        "",
    ]
    if candidate_calls:
        lines.append("## Candidate recombinant samples")
        for row in candidate_calls:
            lines.append(
                f"- {row['sample_id']}: corrected p={row['corrected_p']}, parents={row['candidate_major_parent']} / "
                f"{row['candidate_minor_parent']}, breakpoint={row['candidate_breakpoint']}"
            )
        lines.append("")
    elif inconclusive:
        lines.append("## Inconclusive samples")
        for row in inconclusive:
            lines.append(
                f"- {row['sample_id']}: 3SEQ signal present, but final call downgraded by "
                f"tree/read confirmation ({row['evidence_summary']})"
            )
        lines.append("")
    else:
        lines.append("## Result")
        lines.append(
            "No sample cleared the full high-specificity confirmation stack. Any GARD signal should be treated as alignment-level only."
        )
        lines.append("")
    if breakpoint_rows:
        lines.append("## GARD breakpoints")
        for row in breakpoint_rows:
            lines.append(
                f"- {row['breakpoint_site']} ({row['left_interval']} | {row['right_interval']}), "
                f"support={row['site_support']}, strength={row['support_strength']}"
            )
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    manifest_rows = [row for row in read_tsv(Path(args.manifest_tsv)) if row.get("hpv_type") == args.hpv_type]
    duplicate_rows = read_tsv(Path(args.duplicate_map_tsv))
    gard_breakpoints = read_tsv(Path(args.gard_breakpoints_tsv))
    gard_summary = read_json(Path(args.gard_summary_json))
    three_seq_rows = read_tsv(Path(args.three_seq_candidates_tsv))
    tree_rows = {row["candidate_id"]: row for row in read_tsv(Path(args.tree_confirmation_tsv))}
    read_rows = {row["candidate_id"]: row for row in read_tsv(Path(args.read_validation_tsv))}
    nearest_lineages = load_nearest_lineages(Path(args.samples_vs_lineage_sets_tsv), args.hpv_type)
    nearest_database = load_nearest_database_ids(Path(args.samples_vs_database_tsv))

    duplicate_groups = invert_duplicate_map(manifest_rows)
    representative_candidates = {
        row["candidate_record_id"]: row
        for row in three_seq_rows
        if row.get("eligible_sample_candidate") == "yes" and row.get("candidate_sequence_role") == "sample"
    }

    delta_aicc = parse_float(gard_summary.get("delta_aicc_vs_no_breakpoint"))
    gard_positive = (gard_summary.get("n_breakpoints", 0) or 0) > 0 and (delta_aicc or 0) > 0
    global_strength = classify_global_strength(delta_aicc)

    breakpoint_support_rows: list[dict[str, Any]] = []
    event_rows: list[dict[str, Any]] = []
    for row in gard_breakpoints:
        breakpoint_support_rows.append(
            {
                "analysis_group": args.analysis_group,
                "type_compound_id": f"{args.analysis_group}:{row['breakpoint_id']}",
                "hpv_type": args.hpv_type,
                "breakpoint_id": row["breakpoint_id"],
                "breakpoint_site": row["breakpoint_site"],
                "left_interval": f"{row['left_segment_start']}-{row['left_segment_end']}",
                "right_interval": f"{row['right_segment_start']}-{row['right_segment_end']}",
                "site_support": row.get("site_support", ""),
                "support_strength": row.get("support_strength", ""),
                "delta_aicc_vs_no_breakpoint": row.get("delta_aicc_vs_no_breakpoint", ""),
                "best_model_aicc": row.get("best_model_aicc", ""),
                "evidence_source": "GARD",
            }
        )
        event_rows.append(
            {
                "analysis_group": args.analysis_group,
                "hpv_type": args.hpv_type,
                "event_id": row["breakpoint_id"],
                "event_type": "alignment_breakpoint",
                "breakpoint_site": row["breakpoint_site"],
                "supporting_methods": "GARD",
                "strength": row.get("support_strength", ""),
            }
        )

    candidate_sample_rows: list[dict[str, Any]] = []
    warnings: list[dict[str, str]] = []
    sample_rows = [row for row in manifest_rows if row["sequence_role"] == "sample"]

    for sample_row in sample_rows:
        sample_id = sample_row["sample_id"]
        candidate = determine_candidate_record(sample_row, representative_candidates, duplicate_groups)
        tree = tree_rows.get(candidate["candidate_id"]) if candidate else None
        read = read_rows.get(candidate["candidate_id"]) if candidate else None
        has_candidate_signal = candidate is not None
        tree_confirmed = bool(tree and tree.get("tree_confirmation_status") == "confirmed" and tree.get("bootstrap_pass") == "yes")
        read_passed = bool(read and read.get("read_validation_status") == "pass")
        final_status = "candidate_recombinant"
        if not has_candidate_signal:
            final_status = "alignment_signal_only" if gard_positive else "no_evidence"
        elif not (gard_positive and tree_confirmed and read_passed):
            final_status = "inconclusive"

        evidence_flags = []
        if gard_positive:
            evidence_flags.append("GARD")
        if has_candidate_signal:
            evidence_flags.append("3SEQ")
        if tree_confirmed:
            evidence_flags.append("IQ-TREE")
        if read_passed:
            evidence_flags.append("reads")

        nearest_lineage = nearest_lineages.get(sample_id, {})
        candidate_sample_rows.append(
            {
                "sample_compound_id": f"{args.analysis_group}:{sample_id}",
                "analysis_group": args.analysis_group,
                "hpv_type": args.hpv_type,
                "sample_id": sample_id,
                "collapsed_into": sample_row["collapsed_into"],
                "final_status": final_status,
                "candidate_major_parent": "" if candidate is None else candidate["parent_major_record_id"],
                "candidate_minor_parent": "" if candidate is None else candidate["parent_minor_record_id"],
                "corrected_p": "" if candidate is None else candidate["corrected_p"],
                "candidate_breakpoint": "" if candidate is None else candidate.get("candidate_breakpoint_site", ""),
                "gard_delta_aicc": "" if delta_aicc is None else f"{delta_aicc:.6f}",
                "gard_global_strength": global_strength,
                "tree_confirmation_status": "" if tree is None else tree.get("tree_confirmation_status", ""),
                "tree_support_left": "" if tree is None else tree.get("left_support", ""),
                "tree_support_right": "" if tree is None else tree.get("right_support", ""),
                "read_validation_status": "" if read is None else read.get("read_validation_status", ""),
                "informative_sites": "" if read is None else read.get("informative_site_count", ""),
                "nearest_lineage": nearest_lineage.get("lineage", ""),
                "nearest_lineage_jaccard": nearest_lineage.get("jaccard", ""),
                "nearest_database_ids": nearest_database.get(sample_id, ""),
                "evidence_summary": ",".join(evidence_flags) if evidence_flags else "none",
                "alignment_recombination_signal": "yes" if gard_positive else "no",
                "sample_specific_p_value_available": "yes" if candidate is not None else "no",
            }
        )

    if gard_positive and not any(row["final_status"] == "candidate_recombinant" for row in candidate_sample_rows):
        warnings.append(
            {
                "warning_code": "alignment_signal_only",
                "message": f"{args.hpv_type} has alignment-level recombination evidence, but no sample passed the full confirmation stack.",
            }
        )

    overview_row = {
        "type_compound_id": args.analysis_group,
        "analysis_group": args.analysis_group,
        "hpv_type": args.hpv_type,
        "sample_sequences": sum(1 for row in manifest_rows if row["sequence_role"] == "sample"),
        "background_references": sum(1 for row in manifest_rows if row["sequence_role"] == "background"),
        "collapsed_sequences": sum(1 for row in manifest_rows if row["included_in_collapsed"] == "yes"),
        "duplicate_sequences": len(duplicate_rows),
        "gard_breakpoints": gard_summary.get("n_breakpoints", 0),
        "gard_delta_aicc": "" if delta_aicc is None else f"{delta_aicc:.6f}",
        "gard_global_strength": global_strength,
        "three_seq_candidates": len([row for row in three_seq_rows if row.get("candidate_sequence_role") == "sample"]),
        "three_seq_eligible_candidates": len(representative_candidates),
        "candidate_recombinant_samples": sum(1 for row in candidate_sample_rows if row["final_status"] == "candidate_recombinant"),
        "inconclusive_samples": sum(1 for row in candidate_sample_rows if row["final_status"] == "inconclusive"),
        "alignment_signal_only_samples": sum(1 for row in candidate_sample_rows if row["final_status"] == "alignment_signal_only"),
    }

    Path(args.output_summary_md).write_text(
        build_markdown(args.hpv_type, overview_row, candidate_sample_rows, breakpoint_support_rows),
        encoding="utf-8",
    )
    Path(args.output_events_json).write_text(__import__("json").dumps(event_rows, indent=2) + "\n", encoding="utf-8")
    write_tsv(Path(args.output_events_tsv), event_rows, ["analysis_group", "hpv_type", "event_id", "event_type", "breakpoint_site", "supporting_methods", "strength"])
    with Path(args.output_events_csv).open("w", encoding="utf-8", newline="") as handle:
        import csv

        writer = csv.DictWriter(
            handle,
            fieldnames=["analysis_group", "hpv_type", "event_id", "event_type", "breakpoint_site", "supporting_methods", "strength"],
        )
        writer.writeheader()
        for row in event_rows:
            writer.writerow(row)
    write_tsv(Path(args.output_warnings_tsv), warnings, ["warning_code", "message"])
    write_tsv(Path(args.output_type_overview_tsv), [overview_row], list(overview_row.keys()))
    write_tsv(Path(args.output_candidate_samples_tsv), candidate_sample_rows, list(candidate_sample_rows[0].keys()) if candidate_sample_rows else [
        "sample_compound_id",
        "analysis_group",
        "hpv_type",
        "sample_id",
        "collapsed_into",
        "final_status",
        "candidate_major_parent",
        "candidate_minor_parent",
        "corrected_p",
        "candidate_breakpoint",
        "gard_delta_aicc",
        "gard_global_strength",
        "tree_confirmation_status",
        "tree_support_left",
        "tree_support_right",
        "read_validation_status",
        "informative_sites",
        "nearest_lineage",
        "nearest_lineage_jaccard",
        "nearest_database_ids",
        "evidence_summary",
        "alignment_recombination_signal",
        "sample_specific_p_value_available",
    ])
    write_tsv(Path(args.output_breakpoint_support_tsv), breakpoint_support_rows, list(breakpoint_support_rows[0].keys()) if breakpoint_support_rows else [
        "analysis_group",
        "type_compound_id",
        "hpv_type",
        "breakpoint_id",
        "breakpoint_site",
        "left_interval",
        "right_interval",
        "site_support",
        "support_strength",
        "delta_aicc_vs_no_breakpoint",
        "best_model_aicc",
        "evidence_source",
    ])
    write_tsv(Path(args.output_duplicate_map_tsv), duplicate_rows, list(duplicate_rows[0].keys()) if duplicate_rows else [
        "analysis_group",
        "hpv_type",
        "collapsed_into",
        "duplicate_record_id",
        "sequence_role",
        "background_source",
        "display_name",
        "sequence_hash",
        "reason",
    ])
    return 0


if __name__ == "__main__":
    sys.exit(main())
