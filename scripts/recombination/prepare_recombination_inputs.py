#!/usr/bin/env python3
"""Prepare recombination FASTA inputs from metadata-driven sequence lists."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Iterable

from Bio import SeqIO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sequences-tsv", required=True, help="TSV/CSV with sequence paths")
    parser.add_argument("--output-fasta", required=True)
    parser.add_argument("--output-manifest", required=True)
    parser.add_argument("--output-excluded", required=True)
    parser.add_argument("--output-summary-json", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--exclude-samples-tsv")
    parser.add_argument("--exclude-pattern", default=None)
    parser.add_argument("--skip-controls", action="store_true")
    parser.add_argument("--hpv-types", default=None, help="Comma-separated allowlist")
    parser.add_argument("--min-sequences", type=int, default=3)
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


def sanitize_record_id(value: str) -> str:
    compact = re.sub(r"\s+", "_", value.strip())
    compact = re.sub(r"[^A-Za-z0-9_.:|+-]", "_", compact)
    return compact or "record"


def write_tsv(path: Path, rows: list[dict[str, object]], headers: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    args = parse_args()

    repo_root = Path(args.repo_root).resolve()
    sequences_path = Path(args.sequences_tsv).resolve()
    exclude_list_path = Path(args.exclude_samples_tsv).resolve() if args.exclude_samples_tsv else None

    if not sequences_path.exists():
        raise SystemExit(f"Sequence table not found: {sequences_path}")

    delimiter = detect_delimiter(sequences_path)
    excluded_samples = load_exclude_samples(exclude_list_path)
    allow_hpv = parse_allowlist(args.hpv_types)
    exclude_re = re.compile(args.exclude_pattern, flags=re.IGNORECASE) if args.skip_controls and args.exclude_pattern else None

    included_rows: list[dict[str, object]] = []
    excluded_rows: list[dict[str, object]] = []
    sequence_count = 0
    manifest_count = 0

    with sequences_path.open("r", encoding="utf-8", newline="") as handle, Path(args.output_fasta).open(
        "w", encoding="utf-8"
    ) as fasta_out:
        reader = csv.DictReader(handle, delimiter=delimiter)
        if not reader.fieldnames:
            raise SystemExit(f"No header found in {sequences_path}")
        col = resolve_columns(reader.fieldnames)

        for row in reader:
            run_id = (row.get(col["run_id"]) or "run").strip() if col["run_id"] else "run"
            sample_id = (row.get(col["sample_id"]) or "").strip()
            hpv_type = (row.get(col["hpv_type"]) or "").strip() if col["hpv_type"] else ""
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

            records = list(SeqIO.parse(str(resolved_fasta), "fasta"))
            if not records:
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

            for rec in records:
                source_id = sanitize_record_id(rec.id)
                normalized_id = sanitize_record_id(f"{run_id}:{sample_id}|{source_id}")
                seq = str(rec.seq).upper().replace("U", "T")
                fasta_out.write(f">{normalized_id}\n{seq}\n")
                included_rows.append(
                    {
                        "run_id": run_id,
                        "sample_id": sample_id,
                        "hpv_type": hpv_type,
                        "source_fasta": str(resolved_fasta),
                        "source_record_id": source_id,
                        "normalized_record_id": normalized_id,
                        "sequence_length": len(seq),
                    }
                )
                sequence_count += 1
            manifest_count += 1

    write_tsv(
        Path(args.output_manifest),
        included_rows,
        [
            "run_id",
            "sample_id",
            "hpv_type",
            "source_fasta",
            "source_record_id",
            "normalized_record_id",
            "sequence_length",
        ],
    )
    write_tsv(
        Path(args.output_excluded),
        excluded_rows,
        ["run_id", "sample_id", "hpv_type", "fasta_path", "reason"],
    )

    summary = {
        "input_table": str(sequences_path),
        "manifest_rows": manifest_count,
        "included_records": sequence_count,
        "excluded_rows": len(excluded_rows),
        "skip_controls": bool(args.skip_controls),
        "exclude_pattern": args.exclude_pattern,
        "hpv_allowlist": sorted(allow_hpv) if allow_hpv else None,
    }
    Path(args.output_summary_json).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if sequence_count < args.min_sequences:
        raise SystemExit(
            "Not enough sequences for recombination analysis: "
            f"{sequence_count} < {args.min_sequences}."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
