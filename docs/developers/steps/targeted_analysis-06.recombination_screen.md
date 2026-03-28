# targeted_analysis step 06: Recombination screen

## Overview

This step prepares HPV-specific recombination screening groups and runs the
faster front half of the workflow:

- per-HPV-type input preparation from metadata
- same-type tree-selected background references
- exact-duplicate collapsing and manifest generation
- MAFFT alignment or alignment passthrough
- optional pairwise-identity plots
- HyPhy GARD breakpoint screening
- stage-level screening tables, handoff manifest, and MultiQC report

This stage does not make sample-level recombinant calls.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/06.recombination_screen.run.sh`
- Step config JSON: `config/steps/targeted_analysis.06.recombination_screen.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_screen`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- User parameters: `config/user.config` (keys prefixed with `recombination_`)

## Inputs

- Metadata sequence table:
  - `metadata/recombination_analysis/sequence_sets/targeted_analysis.recombination_sequences.tsv`
  - required columns: `run_id`, `sample_id`, `hpv_type`, `fasta_path`
- Optional explicit exclusion list:
  - `metadata/recombination_analysis/exclude_lists/default_controls.txt`
- Same-type background references:
  - `derived_data/refdata/hpv16_tree/selected_renamed.fasta`
  - `derived_data/refdata/hpv18_tree/selected_renamed.fasta`

`fasta_path` entries can be absolute paths or repo-relative paths.

## Outputs

Primary output root:

- `outs/targeted_analysis/06.recombination_screen/`

Subdirectories:

- `alignment/`: per-type aligned FASTA files
- `gard/`: GARD raw output, parsed breakpoint tables, summaries, warnings, logs
- `plots/`: optional pairwise-identity tables, plots, and warnings
- `summary/`: screen-level overview tables, warnings, and `recombination_screen_groups.tsv`
- `reports/`: MultiQC-ready stage tables and markdown summary

MultiQC report:

- `results/reports/targeted_analysis/06_recombination_screen.report.html`

## Notes

- Default filtering excludes technical artifacts (`H2O`, `HPV-110`, `Ex`,
  `HPV-19`, `Undetermined*`) unless the user disables this behavior.
- Stage 07 consumes the published `summary/recombination_screen_groups.tsv`
  handoff rather than any Nextflow work directory paths.
