---
name: phylo-tree-operations
description: Run and troubleshoot HPV16/HPV18 phylogenetic tree generation and reporting in this repository, including outgroup handling, bcf_run_id selection, output placement, and MultiQC preview integration.
---

# Phylogenetic Tree Operations

Use this skill when changing or debugging `pipelines/phylo_tree.nf`, step wrappers
for `04.hpv16_tree` / `05.hpv18_tree`, or related report assets.

## Inputs and prerequisites

- Tree refdata roots:
  - `derived_data/refdata/hpv16_tree`
  - `derived_data/refdata/hpv18_tree`
- Outgroup lists:
  - `metadata/hpv16_tree/hpv16_tree_outgroups.txt`
  - `metadata/hpv18_tree/hpv18_tree_outgroups.txt`
- If mapping outputs include multiple run IDs, set `bcf_run_id` in
  `config/analyses/targeted_analysis.config`.

## Output contract

- Step outputs are under `outs/targeted_analysis/04.hpv16_tree` and
  `outs/targeted_analysis/05.hpv18_tree`.
- Tree images must be at step root:
  - `phylo_tree.svg`
  - `phylo_tree.png`
- MultiQC helper tables stay under `<step>/reports/`.
- MultiQC HTML report path is `results/reports/targeted_analysis/`.
- MultiQC should embed an offline-resolvable preview of the tree image.
- Optional lineage annotation uses lineage reference tables in
  `metadata/hpv16_tree/` and `metadata/hpv18_tree/`.

## Rendering policy

- Default to branch-length-agnostic rendering (topology-depth style) to avoid
  extreme skew from distant outgroups.
- Use branch-length-scaled rendering only when explicitly requested.

## Troubleshooting checklist

1. `outgroups.fasta` exists and is non-empty.
2. `phylo_tree.svg/.png` are at step root, not `reports/`.
3. MultiQC config points to the actual tree image locations.
4. If tree labels cluster incorrectly, verify rendering mode and label spacing
   settings in the plotting helper script.
