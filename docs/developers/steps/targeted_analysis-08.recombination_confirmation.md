# targeted_analysis step 08: Recombination confirmation

## Overview

This step runs the final confirmation workflow on published stage-07 outputs:

- breakpoint-window IQ-TREE confirmation
- read-level validation against step-02 mapping outputs
- per-type recombination event summarization
- final aggregate tables and markdown summary
- final MultiQC report

Only this stage can emit final candidate recombinant calls.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/08.recombination_confirmation.run.sh`
- Step config JSON: `config/steps/targeted_analysis.08.recombination_confirmation.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_confirmation`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- User parameters: `config/user.config` (keys prefixed with `recombination_`)

## Inputs

- Published stage-07 handoff:
  - `outs/targeted_analysis/07.recombination_openrdp/summary/recombination_openrdp_groups.tsv`
- Upstream confirmation context:
  - `outs/targeted_analysis/02.mapping_vs_pave/targeted_analysis/*.bam`
  - `outs/targeted_analysis/03.variant_analysis/reports/samples_vs_lineage_sets.tsv`
  - `outs/targeted_analysis/03.variant_analysis/reports/samples_vs_database.tsv`

## Outputs

Primary output root:

- `outs/targeted_analysis/08.recombination_confirmation/`

Subdirectories:

- `trees/`: breakpoint-window IQ-TREE confirmation tables
- `read_validation/`: per-candidate read validation tables
- `summary/`: per-type and aggregate event tables, warnings, and markdown
- `reports/`: final MultiQC-ready recombination tables and markdown summary

MultiQC report:

- `results/reports/targeted_analysis/08_recombination_confirmation.report.html`

## Notes

- Final interpretation remains conservative: HPV recombination signals are rare
  and can be confounded by alignment problems, mixed infections,
  contamination, and consensus artifacts.
