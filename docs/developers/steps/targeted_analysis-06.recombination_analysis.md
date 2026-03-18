# targeted_analysis step 06: Recombination analysis

## Overview

This step performs HPV-specific recombination confirmation using:

- per-HPV-type alignment construction
- same-type tree-selected background references
- MAFFT alignment
- HyPhy GARD breakpoint screening
- 3SEQ sample-level mosaic testing
- IQ-TREE breakpoint-window confirmation
- mapped-read validation against step-02 BAMs
- machine-readable and markdown summary generation
- optional pairwise-identity visualization

RDP/SimPlot are intentionally not automated in this step.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/06.recombination_analysis.run.sh`
- Step config JSON: `config/steps/targeted_analysis.06.recombination_analysis.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_analysis`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- User parameters: `config/user.config` (keys prefixed with `recombination_`)

## Inputs

- Metadata sequence table (required):
  - `metadata/recombination_analysis/sequence_sets/targeted_analysis.recombination_sequences.tsv`
  - required columns: `run_id`, `sample_id`, `hpv_type`, `fasta_path`
- Optional explicit exclusion list:
  - `metadata/recombination_analysis/exclude_lists/default_controls.txt`
- Same-type background references (auto-included by default):
  - `derived_data/refdata/hpv16_tree/selected_renamed.fasta`
  - `derived_data/refdata/hpv18_tree/selected_renamed.fasta`
- Upstream outputs used for confirmation:
  - `outs/targeted_analysis/02.mapping_vs_pave/targeted_analysis/*.bam`
  - `outs/targeted_analysis/03.variant_analysis/reports/samples_vs_lineage_sets.tsv`
  - `outs/targeted_analysis/03.variant_analysis/reports/samples_vs_database.tsv`

`fasta_path` entries can be absolute paths or repo-relative paths.

## Outputs

Primary output root:

- `outs/targeted_analysis/06.recombination_analysis/`

Subdirectories:

- `alignment/`: per-type MAFFT alignments
- `gard/`: per-type GARD raw output, parsed breakpoints, logs
- `3seq/`: per-type 3SEQ candidate triplets and logs
- `trees/`: IQ-TREE breakpoint-window confirmation artifacts
- `read_validation/`: per-candidate read-level validation summaries
- `summary/`: per-type and aggregated event tables (`TSV/CSV/JSON`) + markdown summary
- `plots/`: optional similarity plot outputs
- `reports/`: selected summary files used for reporting

MultiQC report:

- `results/reports/targeted_analysis/06_recombination_analysis.report.html`

## Notes

- Default filtering excludes technical artifacts (`H2O`, `HPV-110`, `Ex`,
  `HPV-19`, `Undetermined*`) unless the user disables this behavior.
- The workflow splits HPV16 and HPV18 into separate recombination analyses.
- A sample is only labeled `candidate_recombinant` when GARD, 3SEQ, IQ-TREE,
  and read validation agree.
- Interpretation should remain cautious: HPV recombination signals are rare and
  can be confounded by alignment quality, mixed infections, contamination, and
  consensus artifacts.
