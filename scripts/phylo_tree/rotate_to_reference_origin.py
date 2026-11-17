#!/usr/bin/env python3
"""
Rotate circular genomes so that they start at the reference origin.

HPV genomes are circular, and database records do not all start at the same
position. A multiple aligner cannot wrap a sequence, so every genome must
start where the type reference starts before alignment.

Each sequence is compared with the reference through exact k-mers that occur
once in both. In a genome that starts downstream of the reference origin the
matched reference positions run up to the reference end and then jump back to
its start; the bases from that point onwards are moved to the front. No base
is added, removed or changed. Sequences that already start at the origin
(including those with a few extra bases copied from the genome end) are
written unchanged.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple

KMER = 15
MIN_ANCHORS = 20
MAX_START_OVERHANG = 30


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    p.add_argument("--reference", required=True, help="FASTA containing the type reference genome")
    p.add_argument("--reference-name", default=None,
                   help="Use the record whose header starts with this name (default: first record)")
    p.add_argument("--input", required=True, help="Input FASTA (unaligned genomes)")
    p.add_argument("--output", required=True, help="Output FASTA")
    p.add_argument("--report", default=None, help="Optional TSV listing the rotated sequences")
    return p.parse_args()


def read_fasta(path: Path) -> List[Tuple[str, str]]:
    records: List[Tuple[str, List[str]]] = []
    with path.open() as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith(">"):
                records.append((line[1:], []))
            elif records and line.strip():
                records[-1][1].append(line.strip())
    return [(name, "".join(parts)) for name, parts in records]


def write_fasta(path: Path, records: List[Tuple[str, str]], width: int = 70) -> None:
    with path.open("w") as handle:
        for name, seq in records:
            handle.write(f">{name}\n")
            for i in range(0, len(seq), width):
                handle.write(seq[i:i + width] + "\n")


def pick_reference(records: List[Tuple[str, str]], name: Optional[str]) -> str:
    if not records:
        raise SystemExit("Reference FASTA is empty")
    if name is None:
        return records[0][1]
    for header, seq in records:
        if header.startswith(name):
            return seq
    raise SystemExit(f"Reference record not found: {name}")


def shared_unique_kmers(ref: str, qry: str, k: int = KMER) -> List[Tuple[int, int]]:
    """1-based (query, reference) positions of k-mers occurring once in both."""
    circular = ref + ref[:k - 1]
    ref_positions: Dict[str, List[int]] = {}
    for i in range(len(ref)):
        ref_positions.setdefault(circular[i:i + k], []).append(i + 1)
    qry_counts: Dict[str, int] = {}
    for j in range(len(qry) - k + 1):
        kmer = qry[j:j + k]
        qry_counts[kmer] = qry_counts.get(kmer, 0) + 1
    anchors = []
    for j in range(len(qry) - k + 1):
        kmer = qry[j:j + k]
        hits = ref_positions.get(kmer)
        if hits and len(hits) == 1 and qry_counts[kmer] == 1:
            anchors.append((j + 1, hits[0]))
    return anchors


def origin_position(ref: str, qry: str) -> Optional[int]:
    """Position in qry matching reference position 1, if qry is rotated."""
    anchors = shared_unique_kmers(ref.upper(), qry.upper())
    if len(anchors) < MIN_ANCHORS:
        return None
    for (_, r1), (q2, r2) in zip(anchors, anchors[1:]):
        if r1 - r2 > len(ref) / 2:
            origin = q2 - (r2 - 1)
            runs_to_reference_end = anchors[-1][1] > len(ref) / 2
            if origin - 1 <= MAX_START_OVERHANG and runs_to_reference_end:
                return None
            return origin
    return None


def main() -> int:
    args = parse_args()
    ref = pick_reference(read_fasta(Path(args.reference)), args.reference_name)
    report = ["name\tlength\tmoved_to_front_bp"]
    out_records = []
    for name, seq in read_fasta(Path(args.input)):
        origin = origin_position(ref, seq)
        if origin is not None and 1 < origin <= len(seq):
            seq = seq[origin - 1:] + seq[:origin - 1]
            report.append(f"{name.split()[0]}\t{len(seq)}\t{len(seq) - origin + 1}")
        out_records.append((name, seq))
    write_fasta(Path(args.output), out_records)
    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
