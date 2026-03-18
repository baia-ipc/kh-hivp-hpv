#!/usr/bin/env python3
"""Parse HyPhy GARD JSON outputs into normalized TSV/JSON summaries."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import (  # noqa: E402
    classify_breakpoint_support,
    parse_float,
    write_json,
    write_tsv,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-json", required=True)
    parser.add_argument("--output-breakpoints-tsv", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    return parser.parse_args()


def extract_breakpoints(payload: dict[str, Any]) -> tuple[list[int], list[tuple[int, int]]]:
    segments: list[tuple[int, int]] = []
    breakpoint_data = payload.get("breakpointData", {})
    if not isinstance(breakpoint_data, dict):
        return [], []
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
    segments = sorted(set(segments))
    breakpoints = [end for _, end in segments[:-1]]
    return breakpoints, segments


def main() -> int:
    args = parse_args()
    payload = {}
    warnings: list[dict[str, str]] = []
    json_path = Path(args.input_json)

    try:
        payload = __import__("json").loads(json_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        warnings.append({"warning_code": "invalid_json", "message": str(exc)})

    breakpoints, segments = extract_breakpoints(payload)
    support_map = {
        int(key): parse_float(value)
        for key, value in (payload.get("siteBreakPointSupport") or {}).items()
        if str(key).isdigit()
    }

    baseline = parse_float(payload.get("baselineScore"))
    single_tree_aicc = parse_float(payload.get("singleTreeAICc"))
    best_model_aicc = parse_float(payload.get("bestModelAICc"))
    delta_aicc = None
    if single_tree_aicc is not None and best_model_aicc is not None:
        delta_aicc = single_tree_aicc - best_model_aicc

    breakpoint_rows: list[dict[str, object]] = []
    for idx, bp in enumerate(breakpoints, start=1):
        left_start = segments[idx - 1][0] if idx - 1 < len(segments) else 1
        left_end = bp
        right_start = bp + 1
        right_end = segments[idx][1] if idx < len(segments) else ""
        support = support_map.get(bp)
        breakpoint_rows.append(
            {
                "analysis_group": args.analysis_group,
                "hpv_type": args.hpv_type,
                "breakpoint_id": f"{args.analysis_group}_BP_{idx}",
                "breakpoint_site": bp,
                "left_segment_start": left_start,
                "left_segment_end": left_end,
                "right_segment_start": right_start,
                "right_segment_end": right_end,
                "site_support": "" if support is None else f"{support:.6f}",
                "support_strength": classify_breakpoint_support(support),
                "baseline_score": "" if baseline is None else f"{baseline:.6f}",
                "single_tree_aicc": "" if single_tree_aicc is None else f"{single_tree_aicc:.6f}",
                "best_model_aicc": "" if best_model_aicc is None else f"{best_model_aicc:.6f}",
                "delta_aicc_vs_no_breakpoint": "" if delta_aicc is None else f"{delta_aicc:.6f}",
            }
        )

    if not breakpoint_rows:
        warnings.append(
            {
                "warning_code": "no_breakpoints_detected",
                "message": "No breakpoint positions were detected in the GARD JSON payload.",
            }
        )

    write_tsv(
        Path(args.output_breakpoints_tsv),
        breakpoint_rows,
        [
            "analysis_group",
            "hpv_type",
            "breakpoint_id",
            "breakpoint_site",
            "left_segment_start",
            "left_segment_end",
            "right_segment_start",
            "right_segment_end",
            "site_support",
            "support_strength",
            "baseline_score",
            "single_tree_aicc",
            "best_model_aicc",
            "delta_aicc_vs_no_breakpoint",
        ],
    )
    write_tsv(Path(args.output_warnings_tsv), warnings, ["warning_code", "message"])

    summary = {
        "analysis_group": args.analysis_group,
        "hpv_type": args.hpv_type,
        "status": "ok" if breakpoint_rows else "no_breakpoints",
        "breakpoints": breakpoints,
        "segments": [{"start": start, "end": end} for start, end in segments],
        "n_breakpoints": len(breakpoints),
        "baseline_score": baseline,
        "single_tree_aicc": single_tree_aicc,
        "best_model_aicc": best_model_aicc,
        "delta_aicc_vs_no_breakpoint": delta_aicc,
        "time_elapsed_seconds": payload.get("timeElapsed"),
        "total_model_count": payload.get("totalModelCount"),
        "warnings": warnings,
    }
    write_json(Path(args.output_summary_json), summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
