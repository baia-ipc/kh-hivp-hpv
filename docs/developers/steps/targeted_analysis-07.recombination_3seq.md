# targeted_analysis step 07: Recombination 3SEQ

## Overview

This step runs the 3SEQ triplet scan on the published alignments from step 06.
3SEQ tests every parent–parent–child triplet of distinct sequences and reports
the triplets whose mosaic signal survives correction for multiple comparisons.

This step reports 3SEQ evidence only; it makes no final recombinant call.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/07.recombination_3seq.run.sh`
- Step config JSON: `config/steps/targeted_analysis.07.recombination_3seq.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_3seq`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- Runner script: `scripts/recombination/run_3seq.py`
- Summary script: `scripts/recombination/summarize_recombination_3seq.py`

The 3SEQ binary and its p-value table ship with the OpenRDP package installed
in `pipelines/conda_env/recombination.openrdp.env.yml`, so no table is
generated at run time.

## Inputs

- Published stage-06 handoff:
  - `outs/targeted_analysis/06.recombination_screen/summary/recombination_screen_groups.tsv`
- Each row points to the aligned FASTA and the sequence manifest for one HPV
  type.

Ambiguity codes are replaced by `N` before the scan, because 3SEQ accepts only
`A`, `T`, `G`, `C`, `N` and gaps. The substitutions are counted in the summary
JSON.

## Parameters

- `recombination_3seq_pvalue_threshold` (default `0.05`): a sample candidate is
  eligible when its corrected p-value is at or below this value.
- `recombination_3seq_min_segment_length` (default `0`): optional minimum
  length of the mosaic segment, in alignment columns.
- `recombination_3seq_timeout_seconds`: wall-clock limit for the scan.

## Outputs

Primary output root:

- `outs/targeted_analysis/07.recombination_3seq/`

Subdirectories:

- `3seq/`: candidate table, summary JSON, run log, and the raw `.rec` triplet file
- `summary/`: per-type overview, method status, warnings, and
  `recombination_3seq_groups.tsv`
- `reports/`: MultiQC-ready tables and markdown summary

MultiQC report:

- `results/reports/targeted_analysis/07_recombination_3seq.report.html`

## Notes

- An empty candidate table is a valid result. A clean negative conclusion
  requires 3SEQ to exit successfully and to report no eligible sample-level
  candidate; a crash or timeout is recorded as a method failure instead.
- Candidates are reported for sample sequences only. Triplets whose child is a
  background reference are kept in the candidate table but never counted as
  eligible.
