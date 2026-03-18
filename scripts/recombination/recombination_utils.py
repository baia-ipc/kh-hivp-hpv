#!/usr/bin/env python3
"""Shared helpers for the recombination workflow."""

from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from Bio import SeqIO


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def sanitize_record_id(value: str) -> str:
    compact = re.sub(r"\s+", "_", value.strip())
    compact = re.sub(r"[^A-Za-z0-9_.:|+-]", "_", compact)
    return compact or "record"


def sequence_hash(seq: str) -> str:
    normalized = seq.upper().replace("-", "").replace("U", "T")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def parse_fasta(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for record in SeqIO.parse(str(path), "fasta"):
        rows.append(
            {
                "id": str(record.id),
                "description": str(record.description),
                "sequence": str(record.seq).upper().replace("U", "T"),
            }
        )
    return rows


def format_number(value: float | int | None, digits: int = 3) -> str:
    if value is None:
        return "NA"
    return f"{float(value):.{digits}f}"


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


def determine_final_status(
    gard_positive: bool,
    has_candidate_signal: bool,
    tree_confirmed: bool,
    read_passed: bool,
) -> str:
    if has_candidate_signal and gard_positive and tree_confirmed and read_passed:
        return "candidate_recombinant"
    if has_candidate_signal:
        return "inconclusive"
    if gard_positive:
        return "alignment_signal_only"
    return "no_evidence"
