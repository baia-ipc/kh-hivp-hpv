#!/usr/bin/env python3
"""Trim leading/trailing N's from consensus sequences for GenBank submission.

GenBank rejects sequences that begin or end with N. This trims terminal N runs
(keeping interior N's), writes one FASTA per sample into an output directory,
and emits a TSV report of how much was trimmed and which span was kept (1-based,
relative to the input consensus).

Usage:
  trim_consensus_for_genbank.py --out-dir DIR --report TSV <samples.fasta> [...]
"""
import argparse
from pathlib import Path


def read_fasta(path):
    name, seq = None, []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith(">"):
                if name is not None:
                    yield name, "".join(seq)
                name, seq = line[1:].split()[0], []
            elif line:
                seq.append(line)
        if name is not None:
            yield name, "".join(seq)


def trim_terminal_ns(seq):
    n = len(seq)
    start = 0
    while start < n and seq[start] in "Nn":
        start += 1
    end = n
    while end > start and seq[end - 1] in "Nn":
        end -= 1
    return start, end  # 0-based half-open span to keep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+", help="Input FASTA file(s) of consensus sequences")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--width", type=int, default=70, help="FASTA line wrap width")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []

    for inp in args.inputs:
        for name, seq in read_fasta(inp):
            orig = len(seq)
            s, e = trim_terminal_ns(seq)
            kept = seq[s:e]
            if not kept:
                print(f"WARNING: {name} is all-N; skipped")
                continue
            interior_n = kept.upper().count("N")
            lead = s
            trail = orig - e
            out_path = out_dir / f"{name}.fasta"
            with out_path.open("w", encoding="utf-8") as oh:
                oh.write(f">{name}\n")
                for i in range(0, len(kept), args.width):
                    oh.write(kept[i:i + args.width] + "\n")
            rows.append((name, orig, lead, trail, len(kept), interior_n, s + 1, e))

    with open(args.report, "w", encoding="utf-8") as rh:
        rh.write("sample\torig_len\tlead_N_trimmed\ttrail_N_trimmed\tfinal_len\tinterior_N\tkept_start\tkept_end\n")
        for r in rows:
            rh.write("\t".join(str(x) for x in r) + "\n")

    print(f"Wrote {len(rows)} trimmed sequences to {out_dir}")
    print(f"{'sample':<18}{'orig':>7}{'lead':>7}{'trail':>7}{'final':>7}{'intN':>6}  kept_span")
    for name, orig, lead, trail, final, intn, ks, ke in rows:
        print(f"{name:<18}{orig:>7}{lead:>7}{trail:>7}{final:>7}{intn:>6}  {ks}-{ke}")


if __name__ == "__main__":
    main()
