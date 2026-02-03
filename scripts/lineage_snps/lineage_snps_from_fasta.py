#!/usr/bin/env python3
"""
Call lineage SNPs from full-length lineage reference FASTA sequences against a
reference genome, restricted to E6/E7 BED regions.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile


def read_fasta(path):
    name = None
    seq = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if name is not None:
                    yield name, "".join(seq)
                name = line[1:].split()[0]
                seq = []
            else:
                seq.append(line)
        if name is not None:
            yield name, "".join(seq)


def run(cmd, stdin=None, stdout=None):
    subprocess.run(cmd, stdin=stdin, stdout=stdout, check=True)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lineages", required=True, help="Lineage FASTA file")
    parser.add_argument("--ref", required=True, help="Reference FASTA (full PAVE)")
    parser.add_argument("--ref-name", required=True, help="Reference sequence name")
    parser.add_argument("--bed-dir", required=True, help="Directory with pave_hsa.E6/E7.bed")
    parser.add_argument("--header", action="store_true", help="Print header row")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.header:
        print("\t".join(["lineage", "gene", "chrom", "pos", "ref", "alt"]))

    if not os.path.exists(args.lineages):
        return 0

    if not os.path.exists(args.ref):
        raise SystemExit(f"Reference FASTA not found: {args.ref}")

    bed_e6 = os.path.join(args.bed_dir, "pave_hsa.E6.bed")
    bed_e7 = os.path.join(args.bed_dir, "pave_hsa.E7.bed")
    for bed in (bed_e6, bed_e7):
        if not os.path.exists(bed):
            raise SystemExit(f"BED not found: {bed}")

    tmpdir = tempfile.mkdtemp(prefix="lineage_snps_")
    try:
        ref_fasta = os.path.join(tmpdir, "ref.fa")
        with open(ref_fasta, "w") as out:
            found = False
            for name, seq in read_fasta(args.ref):
                if name == args.ref_name:
                    out.write(f">{name}\n{seq}\n")
                    found = True
                    break
        if not found:
            raise SystemExit(f"Reference sequence not found: {args.ref_name}")
        run(["samtools", "faidx", ref_fasta])

        for lineage_id, seq in read_fasta(args.lineages):
            safe_id = lineage_id.replace("/", "_")
            seq_path = os.path.join(tmpdir, f"{safe_id}.fa")
            with open(seq_path, "w") as out:
                out.write(f">{lineage_id}\n{seq}\n")

            sam_path = os.path.join(tmpdir, f"{safe_id}.sam")
            bam_path = os.path.join(tmpdir, f"{safe_id}.bam")
            bcf_path = os.path.join(tmpdir, f"{safe_id}.bcf")

            with open(sam_path, "w") as sam_out:
                run(["minimap2", "-a", ref_fasta, seq_path], stdout=sam_out)
            run(["samtools", "sort", "-o", bam_path, sam_path])

            mpileup = subprocess.Popen(
                ["bcftools", "mpileup", "-Ou", "-f", ref_fasta, bam_path, "-d", "100000"],
                stdout=subprocess.PIPE,
            )
            call = subprocess.Popen(
                ["bcftools", "call", "-mv", "-Ou", "--ploidy", "1"],
                stdin=mpileup.stdout,
                stdout=subprocess.PIPE,
            )
            run(["bcftools", "view", "-v", "snps", "-Ob", "-o", bcf_path], stdin=call.stdout)
            run(["bcftools", "index", bcf_path])
            mpileup.wait()
            call.wait()

            for gene, bed_path in (("E6", bed_e6), ("E7", bed_e7)):
                view = subprocess.run(
                    ["bcftools", "view", "-R", bed_path, "-H", bcf_path],
                    check=True,
                    stdout=subprocess.PIPE,
                    text=True,
                )
                if not view.stdout:
                    continue
                for line in view.stdout.strip().splitlines():
                    fields = line.split("\t")
                    if len(fields) < 5:
                        continue
                    chrom, pos, _id, ref, alt = fields[:5]
                    print("\t".join([lineage_id, gene, chrom, pos, ref, alt]))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())
