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
    parser.add_argument("--gard-json", required=True)
    parser.add_argument("--gard-breakpoints-tsv", required=True)
    parser.add_argument("--gard-summary-json", required=True)
    parser.add_argument("--output-events-tsv", required=True)
    parser.add_argument("--output-events-csv", required=True)
    parser.add_argument("--output-events-json", required=True)
    parser.add_argument("--output-summary-md", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--output-multiqc-tsv", required=True)
    parser.add_argument("--output-breakpoint-multiqc-tsv", required=True)
    parser.add_argument("--output-sample-multiqc-tsv", required=True)
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


def format_number(value: float | None, digits: int = 3) -> str:
    if value is None:
        return "NA"
    return f"{value:.{digits}f}"


def parse_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def classify_global_strength(delta_aicc: float | None) -> str:
    if delta_aicc is None or delta_aicc <= 0:
        return "none"
    if delta_aicc >= 10:
        return "strong"
    if delta_aicc >= 4:
        return "moderate"
    return "weak"


def classify_breakpoint_support(support: float | None) -> str:
    if support is None or support <= 0:
        return "not_reported"
    if support >= 0.5:
        return "high"
    if support >= 0.2:
        return "moderate"
    return "low"


def extract_best_model_breakpoints(gard_json: dict[str, Any]) -> list[int]:
    breakpoint_data = gard_json.get("breakpointData", {})
    segments: list[tuple[int, int]] = []
    if not isinstance(breakpoint_data, dict):
        return []

    for value in breakpoint_data.values():
        if not isinstance(value, dict):
            continue
        for segment in value.get("bps", []):
            if not isinstance(segment, list) or len(segment) < 2:
                continue
            try:
                start = int(segment[0])
                end = int(segment[1])
            except (TypeError, ValueError):
                continue
            segments.append((start, end))

    if not segments:
        return []

    segments = sorted(set(segments))
    return [end for _, end in segments[:-1]]


def build_events(
    breakpoints: list[int],
    confidence: str,
    support_map: dict[int, float],
    global_strength: str,
) -> list[dict[str, Any]]:
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
                "interpretation": (
                    "Alignment-level GARD signal detected; this pipeline does not identify which "
                    "specific sample is recombinant."
                ),
                "site_support": format_number(support_map.get(bp)),
                "support_strength": classify_breakpoint_support(support_map.get(bp)),
                "global_evidence_strength": global_strength,
            }
        )
    return events


def build_markdown(
    manifest: list[dict[str, str]],
    excluded: list[dict[str, str]],
    events: list[dict[str, Any]],
    gard_summary: dict[str, Any],
    global_strength: str,
    delta_aicc: float | None,
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
            f"- Global evidence strength: {global_strength}",
            f"- Delta c-AIC versus no-breakpoint model: {format_number(delta_aicc)}",
            "- Per-strain p-values: not available from this GARD workflow",
            "- Per-strain recombinant assignment: not available from GARD alone",
            "",
            "## Interpretation note",
            "GARD provides alignment-level model-selection evidence, not a direct p-value for each sample.",
            "If alignment-level signal is detected, every included strain appears in the same flagged alignment, but the automated",
            "workflow cannot tell which specific strain is recombinant without additional follow-up analyses.",
            "HPV recombination signals are generally rare. Putative breakpoints should be interpreted cautiously and validated",
            "against alternative explanations such as alignment artifacts, mixed infections, contamination, or low-depth consensus errors.",
            "",
        ]
    )

    return "\n".join(lines)


def build_breakpoint_rows(
    breakpoints: list[int],
    support_map: dict[int, float],
    delta_aicc: float | None,
    best_model_aicc: float | None,
    global_strength: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for idx, bp in enumerate(breakpoints, start=1):
        support = support_map.get(bp)
        rows.append(
            {
                "breakpoint_id": f"BP_{idx}",
                "breakpoint_site": bp,
                "site_support": format_number(support),
                "support_strength": classify_breakpoint_support(support),
                "delta_aicc_vs_no_breakpoint": format_number(delta_aicc),
                "best_model_aicc": format_number(best_model_aicc),
                "p_value": "NA",
                "evidence_source": "GARD",
                "interpretation": (
                    "Alignment-level breakpoint signal. GARD does not assign this breakpoint to a specific sample."
                ),
            }
        )
    return rows


def build_sample_rows(
    manifest: list[dict[str, str]],
    breakpoints: list[int],
    delta_aicc: float | None,
    global_strength: str,
    support_map: dict[int, float],
) -> list[dict[str, Any]]:
    strongest_support = max((support_map.get(bp, 0.0) for bp in breakpoints), default=0.0)
    breakpoint_list = ",".join(str(bp) for bp in breakpoints) if breakpoints else "none"
    signal_detected = "yes" if breakpoints and (delta_aicc or 0) > 0 else "no"
    if signal_detected == "yes":
        interpretation = (
            "This sample was part of an alignment with recombination evidence, but the pipeline cannot "
            "determine whether this specific sample is recombinant."
        )
    else:
        interpretation = "No alignment-level recombination signal was detected."

    rows: list[dict[str, Any]] = []
    for row in manifest:
        run_id = row.get("run_id", "")
        sample_id = row.get("sample_id", "")
        rows.append(
            {
                "sample": f"{run_id}:{sample_id}" if run_id else sample_id,
                "sample_id": sample_id,
                "hpv_type": row.get("hpv_type", ""),
                "alignment_recombination_signal": signal_detected,
                "sample_specific_assignment": "not available from GARD",
                "evidence_source": "GARD",
                "evidence_strength": global_strength if signal_detected == "yes" else "none",
                "delta_aicc_vs_no_breakpoint": format_number(delta_aicc),
                "strongest_breakpoint_support": format_number(strongest_support if strongest_support > 0 else None),
                "reported_breakpoints": breakpoint_list,
                "p_value": "NA",
                "interpretation": interpretation,
            }
        )
    return rows


def main() -> int:
    args = parse_args()
    manifest = read_tsv(Path(args.manifest_tsv))
    excluded = read_tsv(Path(args.excluded_tsv))
    gard_json = read_json(Path(args.gard_json))
    breakpoints_rows = read_tsv(Path(args.gard_breakpoints_tsv))
    gard_summary = read_json(Path(args.gard_summary_json))

    breakpoints = extract_best_model_breakpoints(gard_json)
    fallback_breakpoints: list[int] = []
    for row in breakpoints_rows:
        raw = row.get("breakpoint", "")
        try:
            fallback_breakpoints.append(int(raw))
        except (TypeError, ValueError):
            continue
    if not breakpoints:
        breakpoints = sorted(set(fallback_breakpoints))

    support_map: dict[int, float] = {}
    raw_support = gard_json.get("siteBreakPointSupport", {})
    if isinstance(raw_support, dict):
        for key, value in raw_support.items():
            try:
                support_map[int(key)] = float(value)
            except (TypeError, ValueError):
                continue

    baseline_score = parse_float(gard_json.get("baselineScore"))
    best_model_aicc = parse_float(gard_json.get("bestModelAICc"))
    delta_aicc = (
        baseline_score - best_model_aicc
        if baseline_score is not None and best_model_aicc is not None
        else None
    )
    global_strength = classify_global_strength(delta_aicc)

    gard_summary["n_breakpoints"] = len(set(breakpoints))
    gard_summary["breakpoints"] = sorted(set(breakpoints))
    gard_summary["baseline_aicc"] = baseline_score
    gard_summary["best_model_aicc"] = best_model_aicc
    gard_summary["delta_aicc_vs_no_breakpoint"] = delta_aicc
    gard_summary["global_evidence_strength"] = global_strength

    events = build_events(breakpoints, args.gard_support_confidence, support_map, global_strength)
    warnings: list[dict[str, str]] = []

    if not events:
        warnings.append(
            {
                "warning_code": "no_recombination_events",
                "message": "No candidate breakpoints were detected by the available GARD summaries.",
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
        "site_support",
        "support_strength",
        "global_evidence_strength",
    ]
    write_tsv(Path(args.output_events_tsv), events, event_fields)
    write_csv(Path(args.output_events_csv), events, event_fields)
    Path(args.output_events_json).write_text(json.dumps(events, indent=2) + "\n", encoding="utf-8")
    write_tsv(Path(args.output_warnings_tsv), warnings, ["warning_code", "message"])

    summary_md = build_markdown(manifest, excluded, events, gard_summary, global_strength, delta_aicc)
    Path(args.output_summary_md).write_text(summary_md + "\n", encoding="utf-8")

    breakpoint_rows = build_breakpoint_rows(
        sorted(set(breakpoints)),
        support_map,
        delta_aicc,
        best_model_aicc,
        global_strength,
    )
    write_tsv(
        Path(args.output_breakpoint_multiqc_tsv),
        breakpoint_rows,
        [
            "breakpoint_id",
            "breakpoint_site",
            "site_support",
            "support_strength",
            "delta_aicc_vs_no_breakpoint",
            "best_model_aicc",
            "p_value",
            "evidence_source",
            "interpretation",
        ],
    )

    sample_rows = build_sample_rows(
        manifest,
        sorted(set(breakpoints)),
        delta_aicc,
        global_strength,
        support_map,
    )
    write_tsv(
        Path(args.output_sample_multiqc_tsv),
        sample_rows,
        [
            "sample",
            "sample_id",
            "hpv_type",
            "alignment_recombination_signal",
            "sample_specific_assignment",
            "evidence_source",
            "evidence_strength",
            "delta_aicc_vs_no_breakpoint",
            "strongest_breakpoint_support",
            "reported_breakpoints",
            "p_value",
            "interpretation",
        ],
    )

    excluded_controls = sum(1 for row in excluded if row.get("reason") in {"control_pattern", "exclude_list"})
    metrics = [
        {"metric": "included_records", "value": len(manifest)},
        {"metric": "excluded_rows", "value": len(excluded)},
        {"metric": "excluded_controls", "value": excluded_controls},
        {"metric": "gard_breakpoints", "value": len(set(breakpoints))},
        {"metric": "candidate_events", "value": len(events)},
        {"metric": "delta_aicc_vs_no_breakpoint", "value": format_number(delta_aicc)},
        {"metric": "global_evidence_strength", "value": global_strength},
        {"metric": "per_sample_p_values_available", "value": "false"},
        {"metric": "warnings", "value": len(warnings)},
        {"metric": "rdp_enabled", "value": "false"},
    ]
    write_tsv(Path(args.output_multiqc_tsv), metrics, ["metric", "value"])

    return 0


if __name__ == "__main__":
    sys.exit(main())
