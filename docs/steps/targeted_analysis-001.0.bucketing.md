# targeted_analysis step 001: Centrifuge bucketing

## Overview

This step performs the same Centrifuge-based taxonomic bucketing as
prelim_analysis step 001 (human + RefSeq archaea/bacteria/viral index), but using the
targeted_analysis sample list and input FASTQ layout.

## Implementation

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- User config: `config/user.config`
- Step path config: `bin/config/targeted_analysis.config` (profile `targeted_bucketing`)
- Technical config: `config/pipelines/common.config` + `config/pipelines/centrifuge_bucketing.config`
- Sample list: `metadata/samples-input2.tsv` (normalized `sample_id` plus `fastq_sample_id` for raw filename prefixes)

Wrapper:

- `bin/targeted_analysis.steps/001.0.bucketing.run.sh`

## Inputs

The input data for targeted_analysis can be stored either:

- under a per-run `Fastq/` subdirectory, or
- directly in the run directory (flat layout).

This is controlled by the sample sheet entries (see `metadata/samples-input2.tsv`),
which include `fastq_sample_id` to match the original FASTQ filename prefix when
it differs from the normalized `sample_id`.

## Outputs

- Per-run outputs under `output/<RUN_ID>/` (alignments, reports, buckets, etc.)
- Aggregated reports under `reports/`, including `reports/multiqc_report.html`
