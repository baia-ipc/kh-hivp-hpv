# targeted_analysis step 05: HPV18 phylogenetic tree

## Overview

This step builds an HPV18 phylogenetic tree from raw inputs in `refdata/`
and auto-generated derived inputs (outgroups, selected references, samples).

## Implementation

- Pipeline: `pipelines/phylo_tree.nf`
- User config: `config/user.config`
- Step path config: `config/analyses/targeted_analysis.config` (profile `targeted_hpv18_tree`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/phylo_tree.config` + `config/pipelines/phylo_tree.hpv18.config`
- Inputs directory: `derived_data/refdata/hpv18_tree` (derived, wired via technical config)
- Raw inputs directory: `refdata/hpv18_tree`
- Outgroup list: `metadata/hpv18_tree_outgroups.txt`

Wrappers:

- `bin/targeted_analysis.steps/05.hpv18_tree.run.sh`

## Inputs

Raw inputs are expected under `refdata/hpv18_tree/`. The pipeline derives
`derived_data/refdata/hpv18_tree/` automatically if files are missing or older
than the raw inputs (no manual preparation commands required).

## Outputs

- Tree outputs and intermediate artifacts under `output/`
- MultiQC report: `output/reports/multiqc_report.html`
- Tree preview image: `output/reports/phylo_tree.svg` (PNG fallback alongside)
- MultiQC summary table: `output/reports/phylo_tree_summary.multiqc.tsv`
