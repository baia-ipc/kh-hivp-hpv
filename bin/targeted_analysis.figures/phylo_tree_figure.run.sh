#!/usr/bin/env bash
# Draw the combined HPV16 (A) and HPV18 (B) tree figure as PDF and 600 dpi TIFF
# from the outputs of steps 04.hpv16_tree and 05.hpv18_tree.
#
# Needs Python with matplotlib, biopython and pillow, e.g. the environment in
# pipelines/conda_env/recombination.env.yml. Set PYTHON to choose the interpreter.
# Extra arguments are passed to render_publication_tree.py (e.g. --min-support 0).
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"
TREES="$PRJROOT/outs/targeted_analysis"
OUTDIR="$PRJROOT/results/figures/targeted_analysis"
mkdir -p "$OUTDIR"

exec "${PYTHON:-python3}" "$PRJROOT/scripts/phylo_tree/render_publication_tree.py" \
  --panel A HPV16 "$TREES/04.hpv16_tree/phylo_tree.rooted.treefile" "$TREES/04.hpv16_tree/phylo_tree.metadata.tsv" \
  --panel B HPV18 "$TREES/05.hpv18_tree/phylo_tree.rooted.treefile" "$TREES/05.hpv18_tree/phylo_tree.metadata.tsv" \
  --merge-lineages A:B,D --align-bands B \
  --out-pdf "$OUTDIR/phylo_tree.pdf" \
  --out-tiff "$OUTDIR/phylo_tree.tiff" \
  "$@"
