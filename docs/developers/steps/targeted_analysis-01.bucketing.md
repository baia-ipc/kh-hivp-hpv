# targeted_analysis step 01: Centrifuge bucketing

## Overview

This step performs the same Centrifuge-based taxonomic bucketing as
prelim_analysis step 01 (human + RefSeq archaea/bacteria/viral index), but using the
targeted_analysis sample list and input FASTQ layout.

## Implementation

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- User config: `config/user.config`
- Step path config: `config/analyses/targeted_analysis.config` (profile `targeted_bucketing`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/centrifuge_bucketing.config`
- Sample list: `metadata/seq_samples/samples_targeted_analysis.tsv` (normalized `sample_id` plus `fastq_sample_id` for raw filename prefixes)

Wrapper:

- `bin/targeted_analysis.steps/01.bucketing.run.sh`

## Inputs

The input data for targeted_analysis can be stored either:

- under a per-run `Fastq/` subdirectory, or
- directly in the run directory (flat layout).

This is controlled by the sample sheet entries (see `metadata/seq_samples/samples_targeted_analysis.tsv`),
which include `fastq_sample_id` to match the original FASTQ filename prefix when
it differs from the normalized `sample_id`.

## Outputs

- Per-run outputs under `outs/targeted_analysis/01.bucketing/<RUN_ID>/` (alignments, reports, buckets, etc.)
- Aggregated reports under `outs/targeted_analysis/01.bucketing/reports/`
- MultiQC report: `results/reports/targeted_analysis/01_bucketing.report.html`
