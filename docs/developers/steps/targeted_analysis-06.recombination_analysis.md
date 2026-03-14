# targeted_analysis step 06: Recombination analysis

## Overview

This step performs metadata-driven HPV recombination screening using:

- MAFFT alignment
- HyPhy GARD breakpoint inference
- machine-readable and markdown summary generation
- optional pairwise-identity visualization

RDP is intentionally not automated in this step.

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

`fasta_path` entries can be absolute paths or repo-relative paths.

## Outputs

Primary output root:

- `outs/targeted_analysis/06.recombination_analysis/`

Subdirectories:

- `alignment/`: MAFFT alignment (`recombination.aln.fasta`)
- `gard/`: GARD raw output, parsed breakpoints, logs
- `summary/`: event tables (`TSV/CSV/JSON`) + markdown summary
- `plots/`: optional similarity plot outputs
- `reports/`: selected summary files used for reporting

MultiQC report:

- `results/reports/targeted_analysis/06_recombination_analysis.report.html`

## Notes

- Default filtering excludes technical artifacts (`H2O`, `HPV-110`, `Ex`,
  `HPV-19`, `Undetermined*`) unless the user disables this behavior.
- Interpretation should remain cautious: HPV recombination signals are rare and
  can be confounded by alignment quality, mixed infections, and contamination.
