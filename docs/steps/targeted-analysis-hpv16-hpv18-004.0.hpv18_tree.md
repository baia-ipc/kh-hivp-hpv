# targeted-analysis-hpv16-hpv18 step 004: HPV18 phylogenetic tree

## Overview

This step builds an HPV18 phylogenetic tree from prepared sequence inputs
(references + selected outgroups + sample consensus sequences).

## Implementation

- Pipeline: `pipelines/phylo_tree.nf`
- User config: `config/user.config`
- Step path config: `bin/config/targeted-analysis-hpv16-hpv18.config` (profile `targeted_hpv18_tree`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/phylo_tree.config` + `config/pipelines/phylo_tree.hpv18.config`
- Inputs directory: `intermediate_files/refdata/hpv18_tree` (wired via technical config)
- Outgroup list: `metadata/hpv18_tree_outgroups.txt`

Wrappers:

- `bin/targeted-analysis-hpv16-hpv18.steps/004.0.hpv18_tree.run.sh`

## Inputs

Inputs are expected under `intermediate_files/refdata/hpv18_tree/` and are prepared from
raw inputs under `refdata/hpv18_tree/` using scripts documented in the
repository root `README.md`.

Sample IDs are derived automatically by `scripts/hpv18_prepare_samples.sh` from
`targeted-analysis-hpv16-hpv18/002.0.mapping_vs_pave/reports/strains.tsv`, selecting samples
whose top strain is HPV18 for the configured run ID.

## Outputs

- Tree outputs and intermediate artifacts under `output/`
- MultiQC report: `output/reports/multiqc_report.html`
