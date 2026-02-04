#!/usr/bin/env python3
"""Compute summary stats for phylogenetic tree inputs and alignments."""
import argparse
import re
from pathlib import Path

from Bio import Phylo


def read_fasta_sequences(path):
    sequences = []
    seq = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if seq:
                    sequences.append("".join(seq))
                    seq = []
                continue
            seq.append(line)
        if seq:
            sequences.append("".join(seq))
    return sequences


def count_fasta_records(path):
    count = 0
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith(">"):
                count += 1
    return count


def alignment_stats(seqs):
    if not seqs:
        return {
            "length": 0,
            "gap_fraction": 0.0,
            "variable_sites": 0,
            "parsimony_informative": 0,
            "constant_sites": 0,
            "missing_sites": 0,
        }

    length = len(seqs[0])
    for seq in seqs:
        if len(seq) != length:
            raise ValueError("Alignment sequences do not have equal length")

    total_cells = len(seqs) * length
    gap_count = sum(seq.count("-") for seq in seqs)
    gap_fraction = gap_count / total_cells if total_cells else 0.0

    variable_sites = 0
    parsimony_informative = 0
    constant_sites = 0
    missing_sites = 0

    for idx in range(length):
        states = []
        for seq in seqs:
            base = seq[idx].upper()
            if base in {"-", "N", "?"}:
                continue
            states.append(base)
        if not states:
            missing_sites += 1
            continue
        counts = {}
        for base in states:
            counts[base] = counts.get(base, 0) + 1
        if len(counts) == 1:
            constant_sites += 1
        else:
            variable_sites += 1
            if sum(1 for v in counts.values() if v >= 2) >= 2:
                parsimony_informative += 1

    return {
        "length": length,
        "gap_fraction": gap_fraction,
        "variable_sites": variable_sites,
        "parsimony_informative": parsimony_informative,
        "constant_sites": constant_sites,
        "missing_sites": missing_sites,
    }


def parse_iqtree_stats(path):
    stats = {
        "best_model": "",
        "log_likelihood": "",
        "tree_length": "",
    }
    if not path or not Path(path).exists():
        return stats

    model_patterns = [
        re.compile(r"Best-fit model according to BIC:\s*(.+)$"),
        re.compile(r"Best-fit model according to AIC:\s*(.+)$"),
        re.compile(r"Best-fit model:\s*(.+)$"),
        re.compile(r"Model of substitution:\s*(.+)$"),
    ]
    number_pattern = re.compile(r"([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)")

    with open(path, "r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not stats["best_model"]:
                for pattern in model_patterns:
                    match = pattern.search(line)
                    if match:
                        stats["best_model"] = match.group(1).strip()
                        break
            if not stats["log_likelihood"] and "Log-likelihood" in line:
                match = number_pattern.search(line)
                if match:
                    stats["log_likelihood"] = match.group(1)
            if not stats["tree_length"] and ("Tree length" in line or "Total tree length" in line or "Sum of branch lengths" in line):
                match = number_pattern.search(line)
                if match:
                    stats["tree_length"] = match.group(1)
    return stats


def format_fraction(value):
    return f"{value:.4f}" if isinstance(value, float) else value


def count_tree_tips(path):
    if not path or not Path(path).exists():
        return ""
    try:
        tree = Phylo.read(path, "newick")
    except Exception:
        return ""
    return len(tree.get_terminals())


def main():
    parser = argparse.ArgumentParser(description="Compute phylogenetic tree summary metrics.")
    parser.add_argument("--selected", required=True, help="Selected reference FASTA")
    parser.add_argument("--outgroups", required=True, help="Outgroups FASTA")
    parser.add_argument("--lineages", required=True, help="Lineage references FASTA")
    parser.add_argument("--samples", required=True, help="Sample consensus FASTA")
    parser.add_argument("--aligned", required=True, help="Aligned FASTA")
    parser.add_argument("--trimmed", required=True, help="Trimmed FASTA")
    parser.add_argument("--iqtree", required=True, help="IQ-TREE report file")
    parser.add_argument("--treefile", required=True, help="Treefile (Newick)")
    parser.add_argument("--output", required=True, help="Output TSV")
    args = parser.parse_args()

    counts = {
        "selected_sequences": count_fasta_records(args.selected),
        "outgroup_sequences": count_fasta_records(args.outgroups),
        "lineage_sequences": count_fasta_records(args.lineages),
        "sample_sequences": count_fasta_records(args.samples),
    }
    counts["total_sequences"] = sum(counts.values())

    aligned_stats = alignment_stats(read_fasta_sequences(args.aligned))
    trimmed_stats = alignment_stats(read_fasta_sequences(args.trimmed))

    retained_pct = ""
    if aligned_stats["length"]:
        retained_pct = trimmed_stats["length"] / aligned_stats["length"] * 100.0

    iqtree_stats = parse_iqtree_stats(args.iqtree)
    tree_tips = count_tree_tips(args.treefile)

    metrics = [
        ("Selected sequences", counts["selected_sequences"]),
        ("Outgroup sequences", counts["outgroup_sequences"]),
        ("Lineage sequences", counts["lineage_sequences"]),
        ("Sample sequences", counts["sample_sequences"]),
        ("Total sequences", counts["total_sequences"]),
        ("Aligned length (bp)", aligned_stats["length"]),
        ("Trimmed length (bp)", trimmed_stats["length"]),
        ("Trimmed retained (%)", retained_pct if retained_pct != "" else ""),
        ("Aligned gap fraction", aligned_stats["gap_fraction"]),
        ("Trimmed gap fraction", trimmed_stats["gap_fraction"]),
        ("Trimmed variable sites", trimmed_stats["variable_sites"]),
        ("Trimmed parsimony-informative sites", trimmed_stats["parsimony_informative"]),
        ("Trimmed constant sites", trimmed_stats["constant_sites"]),
        ("Trimmed missing sites", trimmed_stats["missing_sites"]),
        ("Tree tips", tree_tips),
        ("IQ-TREE best-fit model", iqtree_stats["best_model"]),
        ("IQ-TREE log-likelihood", iqtree_stats["log_likelihood"]),
        ("IQ-TREE tree length", iqtree_stats["tree_length"]),
    ]

    with open(args.output, "w", encoding="utf-8") as out:
        out.write("Metric\tValue\n")
        for metric, value in metrics:
            if isinstance(value, float):
                value = format_fraction(value)
            out.write(f"{metric}\t{value}\n")


if __name__ == "__main__":
    main()
