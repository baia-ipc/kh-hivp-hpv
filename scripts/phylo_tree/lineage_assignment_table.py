#!/usr/bin/env python3
"""
Assign each study genome to a sublineage and report the evidence.

Each study genome is assigned to the sublineage of its nearest sublineage
reference, measured as patristic distance on the maximum-likelihood tree.
For every genome the table reports the nearest and next-nearest reference,
the uncorrected pairwise distance (p-distance) from the nearest one, and
the branch support of the node joining the genome to that reference.

Usage:
    lineage_assignment_table.py [options] <treefile> <alignment> <refs_tsv>
                                <samples_fasta>

Arguments:
    <treefile>       Maximum-likelihood tree in Newick format.
    <alignment>      Alignment in FASTA format, used to compute the
                     p-distance. Give the untrimmed whole-genome alignment,
                     so that the p-distance covers the whole genome.
    <refs_tsv>       TSV mapping sublineage name to reference tip label.
    <samples_fasta>  FASTA with the study genomes, used to identify their
                     tips in the tree.

Options:
    -o FILE --output=FILE    Write the table to FILE instead of standard
                             output.
    -g FILE --outgroups=FILE  List of outgroup tips, one per line. When
                             given, the tree is rooted on them before the
                             joining nodes are determined.
    -h --help                Show this help message and exit.
    -V --version             Show the script version and exit.
    -v --verbose             Enable verbose logging.
    -q --quiet               Suppress log output.
"""
import sys
from pathlib import Path
from typing import Dict, List, Optional, TextIO, Tuple

from Bio import Phylo
from Bio.Phylo.BaseTree import Clade, Tree
from docopt import docopt
from loguru import logger

VERSION = "lineage_assignment_table 1.0"

NUCLEOTIDES = frozenset("ACGT")

COLUMNS = (
    "genome",
    "sublineage",
    "nearest_reference",
    "p_distance_percent",
    "compared_positions",
    "patristic_distance",
    "next_reference",
    "next_patristic_distance",
    "distance_ratio",
    "node_support",
)


def set_logger(verbose: bool, quiet: bool) -> None:
    logger.remove()
    if quiet:
        logger.add(lambda msg: None, level="DEBUG")
    elif verbose:
        logger.add(lambda msg: sys.stderr.write(msg), level="INFO")
    else:
        logger.add(lambda msg: sys.stderr.write(msg), level="WARNING")


def read_fasta(path: Path) -> Dict[str, str]:
    """Read a FASTA file into a name -> uppercase sequence mapping."""
    sequences: Dict[str, str] = {}
    name: Optional[str] = None
    chunks: List[str] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line.startswith(">"):
                if name is not None:
                    sequences[name] = "".join(chunks).upper()
                name = line[1:].split()[0]
                chunks = []
            elif name is not None:
                chunks.append(line)
    if name is not None:
        sequences[name] = "".join(chunks).upper()
    return sequences


def read_reference_map(path: Path) -> Dict[str, str]:
    """Read the sublineage -> reference tip label mapping."""
    references: Dict[str, str] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) >= 2:
                references[fields[0]] = fields[1]
    if not references:
        raise ValueError(f"No sublineage references found in {path}")
    return references


def read_name_list(path: Optional[Path]) -> List[str]:
    if path is None:
        return []
    names = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#"):
                names.append(line)
    return names


def strip_version(name: str) -> str:
    """Drop a trailing GenBank version suffix, e.g. NC_001526.4."""
    base, _, suffix = name.rpartition(".")
    return base if base and suffix.isdigit() else name


def index_tips(tip_names: List[str]) -> Dict[str, str]:
    """Index tips under the spellings used by the metadata files.

    Tips are named `<group>/<accession>`, while the reference and outgroup
    lists refer to them by accession without version, or by the PaVE
    identifier of the group. A key is kept only when it is unambiguous.
    """
    index: Dict[str, str] = {name: name for name in tip_names}
    ambiguous = set()
    for name in tip_names:
        aliases = {strip_version(name)}
        group, separator, _ = name.partition("/")
        if separator:
            aliases.add(group)
            aliases.add(f"{group}REF")
        for alias in aliases:
            if alias in index and index[alias] != name:
                ambiguous.add(alias)
            else:
                index[alias] = name
    for alias in ambiguous:
        index.pop(alias, None)
        logger.debug(f"Ambiguous tip alias ignored: {alias}")
    return index


def match_tip(label: str, index: Dict[str, str]) -> Optional[str]:
    """Resolve a label to a tip name, tolerating the known spellings."""
    for candidate in (label, strip_version(label)):
        if candidate in index:
            return index[candidate]
    return None


def p_distance(first: str, second: str) -> Tuple[float, int]:
    """Uncorrected p-distance over positions called in both sequences."""
    compared = 0
    differing = 0
    for one, other in zip(first, second):
        if one in NUCLEOTIDES and other in NUCLEOTIDES:
            compared += 1
            if one != other:
                differing += 1
    if compared == 0:
        return float("nan"), 0
    return differing / compared, compared


def node_support(clade: Clade) -> str:
    """Branch support of a node, as written by IQ-TREE."""
    if clade.confidence is not None:
        return str(clade.confidence)
    return clade.name or "NA"


def rank_references(
    tree: Tree,
    sample: Clade,
    reference_clades: Dict[str, Clade],
) -> List[Tuple[float, str]]:
    """Sublineage references ordered by patristic distance to the sample."""
    distances = [
        (tree.distance(sample, clade), sublineage)
        for sublineage, clade in reference_clades.items()
    ]
    return sorted(distances)


def build_table(
    treefile: Path,
    alignment_path: Path,
    refs_tsv: Path,
    samples_fasta: Path,
    outgroups_file: Optional[Path],
) -> List[Dict[str, str]]:
    tree = Phylo.read(str(treefile), "newick")
    alignment = read_fasta(alignment_path)
    references = read_reference_map(refs_tsv)
    sample_names = list(read_fasta(samples_fasta))

    tips = {tip.name: tip for tip in tree.get_terminals()}
    index = index_tips(list(tips))

    outgroups = []
    for label in read_name_list(outgroups_file):
        resolved = match_tip(label, index)
        if resolved is None:
            logger.warning(f"Outgroup not found in tree: {label}")
        else:
            outgroups.append(resolved)
    if outgroups:
        logger.info(f"Rooting the tree on {len(outgroups)} outgroup tips")
        tree.root_with_outgroup(*outgroups)
        tips = {tip.name: tip for tip in tree.get_terminals()}

    reference_clades: Dict[str, Clade] = {}
    for sublineage, label in references.items():
        resolved = match_tip(label, index)
        if resolved is None:
            logger.warning(
                f"Reference for sublineage {sublineage} not found "
                f"in tree: {label}"
            )
            continue
        reference_clades[sublineage] = tips[resolved]
    if len(reference_clades) < 2:
        raise ValueError(
            "At least two sublineage references must be present in the tree"
        )

    rows: List[Dict[str, str]] = []
    for sample_name in sorted(sample_names):
        resolved = match_tip(sample_name, index)
        if resolved is None:
            logger.warning(f"Study genome not found in tree: {sample_name}")
            continue
        sample_clade = tips[resolved]

        ranked = rank_references(tree, sample_clade, reference_clades)
        (nearest_distance, nearest), (next_distance, following) = ranked[:2]
        nearest_clade = reference_clades[nearest]

        distance, compared = p_distance(
            alignment.get(resolved, ""),
            alignment.get(nearest_clade.name, ""),
        )
        if compared == 0:
            logger.warning(
                f"No positions called in both {resolved} and "
                f"{nearest_clade.name}; p-distance not computed"
            )

        ratio = next_distance / nearest_distance if nearest_distance else 0.0
        joining = tree.common_ancestor(sample_clade, nearest_clade)

        rows.append(
            {
                "genome": resolved,
                "sublineage": nearest,
                "nearest_reference": nearest_clade.name,
                "p_distance_percent": f"{100 * distance:.3f}",
                "compared_positions": str(compared),
                "patristic_distance": f"{nearest_distance:.6f}",
                "next_reference": reference_clades[following].name,
                "next_patristic_distance": f"{next_distance:.6f}",
                "distance_ratio": f"{ratio:.1f}",
                "node_support": node_support(joining),
            }
        )
    return rows


def write_table(rows: List[Dict[str, str]], handle: TextIO) -> None:
    handle.write("\t".join(COLUMNS) + "\n")
    for row in rows:
        handle.write("\t".join(row[column] for column in COLUMNS) + "\n")


def lineage_assignment_table(
    treefile: Path,
    alignment: Path,
    refs_tsv: Path,
    samples_fasta: Path,
    outgroups_file: Optional[Path],
    output: Optional[Path],
) -> None:
    rows = build_table(
        treefile, alignment, refs_tsv, samples_fasta, outgroups_file
    )
    logger.info(f"Assigned {len(rows)} study genomes")
    if output is None:
        write_table(rows, sys.stdout)
    else:
        with output.open("w", encoding="utf-8") as handle:
            write_table(rows, handle)


if __name__ == "__main__":
    args = docopt(__doc__, version=VERSION)
    set_logger(args["--verbose"], args["--quiet"])
    lineage_assignment_table(
        treefile=Path(args["<treefile>"]),
        alignment=Path(args["<alignment>"]),
        refs_tsv=Path(args["<refs_tsv>"]),
        samples_fasta=Path(args["<samples_fasta>"]),
        outgroups_file=(
            Path(args["--outgroups"]) if args["--outgroups"] else None
        ),
        output=Path(args["--output"]) if args["--output"] else None,
    )
