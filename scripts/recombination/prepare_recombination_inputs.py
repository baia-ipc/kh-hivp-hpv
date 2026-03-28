#!/usr/bin/env python3
"""Prepare per-type recombination inputs from sample metadata and tree references."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import (
    parse_fasta,
    sanitize_record_id,
    sequence_hash,
    write_json,
    write_tsv,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sequences-tsv", required=True)
    parser.add_argument("--output-groups-tsv", required=True)
    parser.add_argument("--output-manifest", required=True)
    parser.add_argument("--output-duplicate-map", required=True)
    parser.add_argument("--output-excluded", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--groups-root", required=True)
    parser.add_argument("--exclude-samples-tsv")
    parser.add_argument("--exclude-pattern", default=None)
    parser.add_argument("--skip-controls", action="store_true")
    parser.add_argument("--hpv-types", default=None, help="Comma-separated allowlist")
    parser.add_argument("--min-sequences", type=int, default=3)
    parser.add_argument("--background-mode", default="tree_selected_same_type")
    parser.add_argument("--hpv16-background-fasta", required=True)
    parser.add_argument("--hpv18-background-fasta", required=True)
    return parser.parse_args()


def detect_delimiter(path: Path) -> str:
    if path.suffix.lower() == ".csv":
        return ","
    with path.open("r", encoding="utf-8", newline="") as handle:
        sample = handle.read(4096)
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters="\t,;")
        return dialect.delimiter
    except csv.Error:
        return "\t"


def load_exclude_samples(path: Path | None) -> set[str]:
    if path is None:
        return set()
    if not path.exists():
        raise SystemExit(f"Exclude list not found: {path}")
    excluded: set[str] = set()
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            token = line.strip()
            if not token or token.startswith("#"):
                continue
            excluded.add(token)
    return excluded


def parse_allowlist(raw: str | None) -> set[str] | None:
    if not raw:
        return None
    values = {part.strip().upper() for part in raw.split(",") if part.strip()}
    return values or None


def normalize_header(raw: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", raw.strip().lower()).strip("_")


def resolve_columns(fieldnames: Iterable[str]) -> dict[str, str]:
    normalized = {normalize_header(name): name for name in fieldnames}

    def pick(*candidates: str) -> str | None:
        for candidate in candidates:
            if candidate in normalized:
                return normalized[candidate]
        return None

    mapping = {
        "run_id": pick("run_id", "run", "runid"),
        "sample_id": pick("sample_id", "sample", "sampleid"),
        "hpv_type": pick("hpv_type", "type", "strain", "hpv"),
        "fasta_path": pick("fasta_path", "fasta", "sequence_path", "path", "consensus_fasta"),
    }
    if mapping["sample_id"] is None or mapping["fasta_path"] is None:
        raise SystemExit(
            "Input table must provide columns for sample_id and fasta_path "
            "(accepted aliases: sample/sample_id and fasta_path/fasta/path)."
        )
    return mapping


def resolve_path(raw: str, repo_root: Path) -> Path:
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate
    return (repo_root / candidate).resolve()


def collapse_duplicate_records(records: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    by_hash: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        by_hash[record["sequence_hash"]].append(record)

    manifest_rows: list[dict[str, Any]] = []
    duplicate_rows: list[dict[str, Any]] = []

    for seq_hash, bucket in by_hash.items():
        ordered = sorted(
            bucket,
            key=lambda row: (
                0 if row["sequence_role"] == "sample" else 1,
                str(row["sample_id"]),
                str(row["display_name"]),
            ),
        )
        representative = ordered[0]["normalized_record_id"]
        for idx, row in enumerate(ordered):
            updated = dict(row)
            updated["collapsed_into"] = representative
            updated["included_in_collapsed"] = "yes" if idx == 0 else "no"
            manifest_rows.append(updated)
            if idx > 0:
                duplicate_rows.append(
                    {
                        "analysis_group": row["analysis_group"],
                        "hpv_type": row["hpv_type"],
                        "collapsed_into": representative,
                        "duplicate_record_id": row["normalized_record_id"],
                        "sequence_role": row["sequence_role"],
                        "background_source": row["background_source"],
                        "display_name": row["display_name"],
                        "sequence_hash": seq_hash,
                        "reason": "exact_sequence_duplicate",
                    }
                )

    manifest_rows.sort(key=lambda row: (row["analysis_group"], row["sequence_role"], row["display_name"]))
    duplicate_rows.sort(key=lambda row: (row["analysis_group"], row["collapsed_into"], row["duplicate_record_id"]))
    return manifest_rows, duplicate_rows


def build_sample_rows(
    sequences_path: Path,
    repo_root: Path,
    excluded_samples: set[str],
    allow_hpv: set[str] | None,
    exclude_re: re.Pattern[str] | None,
) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    delimiter = detect_delimiter(sequences_path)
    rows: list[dict[str, Any]] = []
    excluded_rows: list[dict[str, str]] = []

    with sequences_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        if not reader.fieldnames:
            raise SystemExit(f"No header found in {sequences_path}")
        col = resolve_columns(reader.fieldnames)

        for row in reader:
            run_id = (row.get(col["run_id"]) or "run").strip() if col["run_id"] else "run"
            sample_id = (row.get(col["sample_id"]) or "").strip()
            hpv_type = (row.get(col["hpv_type"]) or "").strip().upper() if col["hpv_type"] else ""
            raw_fasta = (row.get(col["fasta_path"]) or "").strip()

            reason = None
            if not sample_id:
                reason = "missing_sample_id"
            elif not raw_fasta:
                reason = "missing_fasta_path"
            elif sample_id in excluded_samples:
                reason = "exclude_list"
            elif exclude_re and exclude_re.search(sample_id):
                reason = "control_pattern"
            elif allow_hpv and hpv_type and hpv_type.upper() not in allow_hpv:
                reason = "hpv_type_filtered"

            resolved_fasta = resolve_path(raw_fasta, repo_root) if raw_fasta else None
            if reason is None and resolved_fasta and not resolved_fasta.exists():
                reason = "fasta_missing"

            if reason is not None:
                excluded_rows.append(
                    {
                        "run_id": run_id,
                        "sample_id": sample_id,
                        "hpv_type": hpv_type,
                        "fasta_path": raw_fasta,
                        "reason": reason,
                    }
                )
                continue

            sample_records = parse_fasta(resolved_fasta)
            if not sample_records:
                excluded_rows.append(
                    {
                        "run_id": run_id,
                        "sample_id": sample_id,
                        "hpv_type": hpv_type,
                        "fasta_path": raw_fasta,
                        "reason": "empty_fasta",
                    }
                )
                continue

            for rec in sample_records:
                source_id = sanitize_record_id(rec["id"])
                normalized_id = sanitize_record_id(f"{hpv_type}|sample|{run_id}:{sample_id}|{source_id}")
                rows.append(
                    {
                        "analysis_group": hpv_type,
                        "run_id": run_id,
                        "sample_id": sample_id,
                        "hpv_type": hpv_type,
                        "sequence_role": "sample",
                        "background_source": "none",
                        "source_fasta": str(resolved_fasta),
                        "source_record_id": source_id,
                        "display_name": f"{run_id}:{sample_id}",
                        "normalized_record_id": normalized_id,
                        "sequence_length": len(rec["sequence"]),
                        "sequence_hash": sequence_hash(rec["sequence"]),
                        "sequence": rec["sequence"],
                    }
                )

    return rows, excluded_rows


def build_background_rows(hpv_type: str, fasta_path: Path, background_mode: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for rec in parse_fasta(fasta_path):
        display_name = rec["description"] if rec["description"] else rec["id"]
        slug = sanitize_record_id(rec["id"])
        rows.append(
            {
                "analysis_group": hpv_type,
                "run_id": "reference",
                "sample_id": rec["id"],
                "hpv_type": hpv_type,
                "sequence_role": "background",
                "background_source": background_mode,
                "source_fasta": str(fasta_path.resolve()),
                "source_record_id": sanitize_record_id(rec["id"]),
                "display_name": display_name,
                "normalized_record_id": sanitize_record_id(f"{hpv_type}|background|{slug}"),
                "sequence_length": len(rec["sequence"]),
                "sequence_hash": sequence_hash(rec["sequence"]),
                "sequence": rec["sequence"],
            }
        )
    return rows


def write_group_files(
    groups_root: Path,
    group_name: str,
    manifest_rows: list[dict[str, Any]],
    duplicate_rows: list[dict[str, Any]],
) -> dict[str, str]:
    group_dir = groups_root / group_name
    group_dir.mkdir(parents=True, exist_ok=True)

    full_input = group_dir / "full_input.fasta"
    representatives = group_dir / "representative_ids.tsv"
    manifest_path = group_dir / "manifest.tsv"
    duplicate_path = group_dir / "duplicate_map.tsv"
    summary_path = group_dir / "group_summary.json"

    with full_input.open("w", encoding="utf-8") as handle:
        for row in manifest_rows:
            handle.write(f">{row['normalized_record_id']}\n{row['sequence']}\n")

    representative_rows = [
        {
            "analysis_group": row["analysis_group"],
            "normalized_record_id": row["normalized_record_id"],
            "display_name": row["display_name"],
        }
        for row in manifest_rows
        if row["included_in_collapsed"] == "yes"
    ]
    write_tsv(representatives, representative_rows, ["analysis_group", "normalized_record_id", "display_name"])

    manifest_to_write = []
    for row in manifest_rows:
        copy = {k: v for k, v in row.items() if k != "sequence"}
        manifest_to_write.append(copy)
    write_tsv(
        manifest_path,
        manifest_to_write,
        [
            "analysis_group",
            "run_id",
            "sample_id",
            "hpv_type",
            "sequence_role",
            "background_source",
            "source_fasta",
            "source_record_id",
            "display_name",
            "normalized_record_id",
            "sequence_length",
            "sequence_hash",
            "collapsed_into",
            "included_in_collapsed",
        ],
    )

    write_tsv(
        duplicate_path,
        duplicate_rows,
        [
            "analysis_group",
            "hpv_type",
            "collapsed_into",
            "duplicate_record_id",
            "sequence_role",
            "background_source",
            "display_name",
            "sequence_hash",
            "reason",
        ],
    )

    summary = {
        "analysis_group": group_name,
        "hpv_type": group_name,
        "sequence_count": len(manifest_rows),
        "collapsed_sequence_count": len(representative_rows),
        "sample_count": sum(1 for row in manifest_rows if row["sequence_role"] == "sample"),
        "reference_count": sum(1 for row in manifest_rows if row["sequence_role"] == "background"),
        "duplicate_count": len(duplicate_rows),
    }
    write_json(summary_path, summary)

    return {
        "analysis_group": group_name,
        "hpv_type": group_name,
        "full_input_fasta": str(full_input.resolve()),
        "manifest_tsv": str(manifest_path.resolve()),
        "duplicate_map_tsv": str(duplicate_path.resolve()),
        "representative_ids_tsv": str(representatives.resolve()),
        "summary_json": str(summary_path.resolve()),
        "sample_count": str(summary["sample_count"]),
        "reference_count": str(summary["reference_count"]),
        "sequence_count": str(summary["sequence_count"]),
        "collapsed_sequence_count": str(summary["collapsed_sequence_count"]),
    }


def main() -> int:
    args = parse_args()

    repo_root = Path(args.repo_root).resolve()
    groups_root = Path(args.groups_root).resolve()
    sequences_path = Path(args.sequences_tsv).resolve()
    exclude_list_path = Path(args.exclude_samples_tsv).resolve() if args.exclude_samples_tsv else None

    if not sequences_path.exists():
        raise SystemExit(f"Sequence table not found: {sequences_path}")

    excluded_samples = load_exclude_samples(exclude_list_path)
    allow_hpv = parse_allowlist(args.hpv_types)
    exclude_re = re.compile(args.exclude_pattern, flags=re.IGNORECASE) if args.skip_controls and args.exclude_pattern else None

    sample_rows, excluded_rows = build_sample_rows(sequences_path, repo_root, excluded_samples, allow_hpv, exclude_re)
    background_fastas = {
        "HPV16": Path(args.hpv16_background_fasta).resolve(),
        "HPV18": Path(args.hpv18_background_fasta).resolve(),
    }

    grouped_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in sample_rows:
        grouped_rows[row["hpv_type"]].append(row)

    for hpv_type in sorted(grouped_rows):
        bg_path = background_fastas.get(hpv_type)
        if not bg_path or not bg_path.exists():
            raise SystemExit(f"Background FASTA for {hpv_type} not found: {bg_path}")
        grouped_rows[hpv_type].extend(build_background_rows(hpv_type, bg_path, args.background_mode))

    group_rows: list[dict[str, str]] = []
    manifest_rows_all: list[dict[str, Any]] = []
    duplicate_rows_all: list[dict[str, Any]] = []

    for hpv_type, group_records in sorted(grouped_rows.items()):
        collapsed_manifest, duplicate_rows = collapse_duplicate_records(group_records)
        collapsed_reps = [row for row in collapsed_manifest if row["included_in_collapsed"] == "yes"]
        sample_rep_count = sum(1 for row in collapsed_reps if row["sequence_role"] == "sample")
        if sample_rep_count < args.min_sequences:
            raise SystemExit(
                f"Not enough representative sample sequences for {hpv_type}: "
                f"{sample_rep_count} < {args.min_sequences}."
            )
        group_rows.append(write_group_files(groups_root, hpv_type, collapsed_manifest, duplicate_rows))
        manifest_rows_all.extend({k: v for k, v in row.items() if k != "sequence"} for row in collapsed_manifest)
        duplicate_rows_all.extend(duplicate_rows)

    write_tsv(
        Path(args.output_groups_tsv),
        group_rows,
        [
            "analysis_group",
            "hpv_type",
            "full_input_fasta",
            "manifest_tsv",
            "duplicate_map_tsv",
            "representative_ids_tsv",
            "summary_json",
            "sample_count",
            "reference_count",
            "sequence_count",
            "collapsed_sequence_count",
        ],
    )
    write_tsv(
        Path(args.output_manifest),
        manifest_rows_all,
        [
            "analysis_group",
            "run_id",
            "sample_id",
            "hpv_type",
            "sequence_role",
            "background_source",
            "source_fasta",
            "source_record_id",
            "display_name",
            "normalized_record_id",
            "sequence_length",
            "sequence_hash",
            "collapsed_into",
            "included_in_collapsed",
        ],
    )
    write_tsv(
        Path(args.output_duplicate_map),
        duplicate_rows_all,
        [
            "analysis_group",
            "hpv_type",
            "collapsed_into",
            "duplicate_record_id",
            "sequence_role",
            "background_source",
            "display_name",
            "sequence_hash",
            "reason",
        ],
    )
    write_tsv(
        Path(args.output_excluded),
        excluded_rows,
        ["run_id", "sample_id", "hpv_type", "fasta_path", "reason"],
    )

    summary = {
        "input_table": str(sequences_path),
        "group_count": len(group_rows),
        "groups": [row["analysis_group"] for row in group_rows],
        "included_records": len(manifest_rows_all),
        "included_representatives": sum(1 for row in manifest_rows_all if row["included_in_collapsed"] == "yes"),
        "excluded_rows": len(excluded_rows),
        "skip_controls": bool(args.skip_controls),
        "exclude_pattern": args.exclude_pattern,
        "hpv_allowlist": sorted(allow_hpv) if allow_hpv else None,
        "background_mode": args.background_mode,
    }
    Path(args.output_summary_json).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
