#!/usr/bin/env python3
"""Parse HyPhy GARD JSON outputs into normalized TSV/JSON summaries."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any


INT_PATTERN = re.compile(r"\d+")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-json", required=True)
    parser.add_argument("--output-breakpoints-tsv", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--output-warnings-tsv", required=True)
    return parser.parse_args()


def parse_ints(value: Any) -> list[int]:
    if value is None:
        return []
    if isinstance(value, bool):
        return []
    if isinstance(value, int):
        return [value]
    if isinstance(value, float):
        return [int(value)] if value.is_integer() else []
    if isinstance(value, str):
        return [int(token) for token in INT_PATTERN.findall(value)]
    return []


def collect_breakpoints(node: Any, context: str = "root") -> list[tuple[int, str]]:
    hits: list[tuple[int, str]] = []
    if isinstance(node, dict):
        for key, value in node.items():
            child_ctx = f"{context}.{key}"
            key_norm = key.lower()
            if "break" in key_norm or key_norm in {"bp", "bps"}:
                for number in parse_ints(value):
                    hits.append((number, child_ctx))
            hits.extend(collect_breakpoints(value, child_ctx))
    elif isinstance(node, list):
        for idx, value in enumerate(node):
            child_ctx = f"{context}[{idx}]"
            hits.extend(collect_breakpoints(value, child_ctx))
    return hits


def write_tsv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    args = parse_args()
    json_path = Path(args.input_json)

    warnings: list[dict[str, str]] = []

    try:
        payload = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        warnings.append({"warning_code": "invalid_json", "message": f"{exc}"})
        payload = {}

    raw_hits = collect_breakpoints(payload)
    filtered_hits = [(bp, src) for bp, src in raw_hits if bp > 0]
    filtered_hits.sort(key=lambda item: item[0])

    unique_breakpoints: list[int] = []
    seen: set[int] = set()
    rows: list[dict[str, object]] = []
    for bp, src in filtered_hits:
        if bp not in seen:
            seen.add(bp)
            unique_breakpoints.append(bp)
        rows.append({"breakpoint": bp, "source": src})

    if not unique_breakpoints:
        warnings.append(
            {
                "warning_code": "no_breakpoints_detected",
                "message": "No breakpoint positions were detected in the GARD JSON payload.",
            }
        )

    write_tsv(Path(args.output_breakpoints_tsv), rows, ["breakpoint", "source"])
    write_tsv(Path(args.output_warnings_tsv), warnings, ["warning_code", "message"])

    summary = {
        "status": "ok" if unique_breakpoints else "no_breakpoints",
        "breakpoints": unique_breakpoints,
        "n_breakpoints": len(unique_breakpoints),
        "n_raw_hits": len(raw_hits),
        "warnings": warnings,
    }
    Path(args.output_summary_json).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
