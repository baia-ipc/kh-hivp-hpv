# targeted_analysis step 07: Recombination GENECONV

## Overview

This step runs the GENECONV scan on the published alignments from step 06.
GENECONV compares sequence pairs and looks for runs of shared polymorphisms
that are longer than chance would explain, which is the signal left by gene
conversion or recombination.

This step reports GENECONV evidence only; it makes no final recombinant call.

## Implementation

- Pipeline: `pipelines/recombination_analysis.nf`
- Wrapper: `bin/targeted_analysis.steps/07.recombination_geneconv.run.sh`
- Step config JSON: `config/steps/targeted_analysis.07.recombination_geneconv.json`
- Analysis profile: `config/analyses/targeted_analysis.config` (`targeted_recombination_geneconv`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/recombination_analysis.config`
- Runner script: `scripts/recombination/run_geneconv.py`
- Summary script: `scripts/recombination/summarize_recombination_geneconv.py`

The GENECONV binary ships with the OpenRDP package installed in
`pipelines/conda_env/recombination.openrdp.env.yml`.

## Inputs

- Published stage-06 handoff:
  - `outs/targeted_analysis/06.recombination_screen/summary/recombination_screen_groups.tsv`
- Each row points to the aligned FASTA and the sequence manifest for one HPV
  type.

Ambiguity codes are replaced by `N` before the scan. The substitutions are
counted in the summary JSON.

## Parameters

The runner writes a GENECONV configuration with `Gscale=1`, which allows
mismatches inside a fragment, and reports the Bonferroni-corrected
Karlin–Altschul p-value for each fragment. Eligibility is then filtered with:

- `recombination_geneconv_pvalue_threshold` (default `0.05`): a sample
  candidate is eligible when its corrected p-value is at or below this value.
- `recombination_geneconv_min_segment_length` (default `0`): optional minimum
  fragment length, in alignment columns.
- `recombination_geneconv_timeout_seconds`: wall-clock limit for the scan.

## Outputs

Primary output root:

- `outs/targeted_analysis/07.recombination_geneconv/`

Subdirectories:

- `geneconv/`: candidate table, summary JSON, run log, and the raw `.frags` file
- `summary/`: per-type overview, method status, warnings, and
  `recombination_geneconv_groups.tsv`
- `reports/`: MultiQC-ready tables and markdown summary

MultiQC report:

- `results/reports/targeted_analysis/07_recombination_geneconv.report.html`

## Notes

- An empty candidate table is a valid result. A clean negative conclusion
  requires GENECONV to exit successfully and to report no eligible sample-level
  candidate.
- Fragments found inside background reference genomes are kept in the candidate
  table but never counted as eligible, since they say nothing about the study
  genomes.
