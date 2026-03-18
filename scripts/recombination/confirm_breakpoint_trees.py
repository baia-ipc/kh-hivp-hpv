#!/usr/bin/env python3
"""Run breakpoint-window IQ-TREE checks for 3SEQ sample candidates."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

from Bio import Phylo, SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.recombination.recombination_utils import read_json, read_tsv, write_tsv  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alignment", required=True)
    parser.add_argument("--candidates-tsv", required=True)
    parser.add_argument("--gard-summary-json", required=True)
    parser.add_argument("--analysis-group", required=True)
    parser.add_argument("--hpv-type", required=True)
    parser.add_argument("--iqtree-bin", default="iqtree")
    parser.add_argument("--model", default="MFP")
    parser.add_argument("--bootstrap-replicates", type=int, default=1000)
    parser.add_argument("--bootstrap-threshold", type=float, default=95.0)
    parser.add_argument("--output-tsv", required=True)
    return parser.parse_args()


def choose_breakpoint(candidate_bp: str, gard_breakpoints: list[int]) -> int | None:
    try:
        candidate = int(candidate_bp)
    except (TypeError, ValueError):
        return gard_breakpoints[0] if gard_breakpoints else None
    if not gard_breakpoints:
        return candidate
    return min(gard_breakpoints, key=lambda value: abs(value - candidate))


def extract_window(records: list[SeqRecord], start: int, end: int) -> list[SeqRecord]:
    subset: list[SeqRecord] = []
    for record in records:
        seq = str(record.seq)[start - 1 : end]
        ungapped = "".join(base for base in seq if base != "-")
        if not ungapped:
            continue
        subset.append(SeqRecord(Seq(seq), id=record.id, description=""))
    return subset


def lca_support(tree: Any, leaf_a: str, leaf_b: str) -> float | None:
    try:
        node = tree.common_ancestor({"name": leaf_a}, {"name": leaf_b})
    except Exception:  # noqa: BLE001
        return None
    confidence = getattr(node, "confidence", None)
    return float(confidence) if confidence is not None else None


def closest_parent(tree: Any, child: str, parents: tuple[str, str]) -> tuple[str | None, float | None]:
    distances: list[tuple[str, float]] = []
    for parent in parents:
        try:
            distances.append((parent, float(tree.distance(child, parent))))
        except Exception:  # noqa: BLE001
            continue
    if not distances:
        return None, None
    distances.sort(key=lambda item: item[1])
    return distances[0]


def run_tree(prefix: str, fasta_path: Path, args: argparse.Namespace) -> Path | None:
    cmd = [
        args.iqtree_bin,
        "-s",
        str(fasta_path),
        "-m",
        args.model,
        "-B",
        str(args.bootstrap_replicates),
        "-nt",
        "AUTO",
        "-pre",
        prefix,
        "-redo",
        "-quiet",
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True, check=False)
    log_path = Path(f"{prefix}.cmd.log")
    log_path.write_text(completed.stdout + ("\n" + completed.stderr if completed.stderr else ""), encoding="utf-8")
    treefile = Path(f"{prefix}.treefile")
    if completed.returncode != 0 or not treefile.exists():
        return None
    return treefile


def main() -> int:
    args = parse_args()
    candidates = [row for row in read_tsv(Path(args.candidates_tsv)) if row.get("eligible_sample_candidate") == "yes"]
    gard_summary = read_json(Path(args.gard_summary_json))
    gard_breakpoints = [int(value) for value in gard_summary.get("breakpoints", [])]
    segments = gard_summary.get("segments", [])

    records = list(SeqIO.parse(args.alignment, "fasta"))
    alignment_length = len(records[0].seq) if records else 0

    rows: list[dict[str, Any]] = []
    for idx, candidate in enumerate(candidates, start=1):
        sample = candidate["candidate_record_id"]
        parents = (candidate["parent_major_record_id"], candidate["parent_minor_record_id"])
        breakpoint_site = choose_breakpoint(candidate.get("candidate_breakpoint_site", ""), gard_breakpoints)
        if breakpoint_site is None:
            rows.append(
                {
                    "analysis_group": args.analysis_group,
                    "hpv_type": args.hpv_type,
                    "candidate_id": candidate["candidate_id"],
                    "candidate_record_id": sample,
                    "breakpoint_site": "",
                    "left_interval": "",
                    "right_interval": "",
                    "left_parent": "",
                    "right_parent": "",
                    "left_support": "",
                    "right_support": "",
                    "tree_confirmation_status": "not_confirmed",
                    "topology_switch": "no",
                    "bootstrap_pass": "no",
                    "notes": "No GARD or 3SEQ breakpoint available for tree confirmation.",
                }
            )
            continue

        left_start = 1
        right_end = alignment_length
        for segment in segments:
            start = int(segment.get("start", 1))
            end = int(segment.get("end", alignment_length))
            if end == breakpoint_site:
                left_start = start
            if start == breakpoint_site + 1:
                right_end = end

        left_records = extract_window(records, left_start, breakpoint_site)
        right_records = extract_window(records, breakpoint_site + 1, right_end)
        if len(left_records) < 4 or len(right_records) < 4:
            rows.append(
                {
                    "analysis_group": args.analysis_group,
                    "hpv_type": args.hpv_type,
                    "candidate_id": candidate["candidate_id"],
                    "candidate_record_id": sample,
                    "breakpoint_site": breakpoint_site,
                    "left_interval": f"{left_start}-{breakpoint_site}",
                    "right_interval": f"{breakpoint_site + 1}-{right_end}",
                    "left_parent": "",
                    "right_parent": "",
                    "left_support": "",
                    "right_support": "",
                    "tree_confirmation_status": "not_confirmed",
                    "topology_switch": "no",
                    "bootstrap_pass": "no",
                    "notes": "Insufficient informative sequences for one or both breakpoint windows.",
                }
            )
            continue

        left_fasta = Path(f"{args.analysis_group}.candidate{idx}.left.fasta")
        right_fasta = Path(f"{args.analysis_group}.candidate{idx}.right.fasta")
        SeqIO.write(left_records, left_fasta, "fasta")
        SeqIO.write(right_records, right_fasta, "fasta")

        left_tree_path = run_tree(f"{args.analysis_group}.candidate{idx}.left", left_fasta, args)
        right_tree_path = run_tree(f"{args.analysis_group}.candidate{idx}.right", right_fasta, args)
        if left_tree_path is None or right_tree_path is None:
            rows.append(
                {
                    "analysis_group": args.analysis_group,
                    "hpv_type": args.hpv_type,
                    "candidate_id": candidate["candidate_id"],
                    "candidate_record_id": sample,
                    "breakpoint_site": breakpoint_site,
                    "left_interval": f"{left_start}-{breakpoint_site}",
                    "right_interval": f"{breakpoint_site + 1}-{right_end}",
                    "left_parent": "",
                    "right_parent": "",
                    "left_support": "",
                    "right_support": "",
                    "tree_confirmation_status": "not_confirmed",
                    "topology_switch": "no",
                    "bootstrap_pass": "no",
                    "notes": "IQ-TREE failed for one or both breakpoint windows.",
                }
            )
            continue

        left_tree = Phylo.read(str(left_tree_path), "newick")
        right_tree = Phylo.read(str(right_tree_path), "newick")
        left_parent, _ = closest_parent(left_tree, sample, parents)
        right_parent, _ = closest_parent(right_tree, sample, parents)
        left_support = lca_support(left_tree, sample, left_parent) if left_parent else None
        right_support = lca_support(right_tree, sample, right_parent) if right_parent else None
        topology_switch = left_parent is not None and right_parent is not None and left_parent != right_parent
        bootstrap_pass = (
            left_support is not None
            and right_support is not None
            and left_support >= args.bootstrap_threshold
            and right_support >= args.bootstrap_threshold
        )
        rows.append(
            {
                "analysis_group": args.analysis_group,
                "hpv_type": args.hpv_type,
                "candidate_id": candidate["candidate_id"],
                "candidate_record_id": sample,
                "breakpoint_site": breakpoint_site,
                "left_interval": f"{left_start}-{breakpoint_site}",
                "right_interval": f"{breakpoint_site + 1}-{right_end}",
                "left_parent": left_parent or "",
                "right_parent": right_parent or "",
                "left_support": "" if left_support is None else f"{left_support:.3f}",
                "right_support": "" if right_support is None else f"{right_support:.3f}",
                "tree_confirmation_status": "confirmed" if topology_switch and bootstrap_pass else "not_confirmed",
                "topology_switch": "yes" if topology_switch else "no",
                "bootstrap_pass": "yes" if bootstrap_pass else "no",
                "notes": "",
            }
        )

    write_tsv(
        Path(args.output_tsv),
        rows,
        [
            "analysis_group",
            "hpv_type",
            "candidate_id",
            "candidate_record_id",
            "breakpoint_site",
            "left_interval",
            "right_interval",
            "left_parent",
            "right_parent",
            "left_support",
            "right_support",
            "tree_confirmation_status",
            "topology_switch",
            "bootstrap_pass",
            "notes",
        ],
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
