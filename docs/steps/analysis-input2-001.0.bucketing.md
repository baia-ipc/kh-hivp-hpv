# analysis-input2 step 001: Centrifuge bucketing

## Overview

This step performs the same Centrifuge-based taxonomic bucketing as
analysis-input1 step 001 (human + RefSeq archaea/bacteria/viral index), but using the
analysis-input2 sample list and input FASTQ layout.

## Implementation

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- User configs: `config/centrifuge_bucketing.config` + `config/analysis-input2_001.bucketing.config`
- Technical config: `pipelines/config/common.technical.config` + `pipelines/config/centrifuge_bucketing.technical.config`
- Sample list: `metadata/samples-input2.tsv` (normalized `sample_id` plus `fastq_sample_id` for raw filename prefixes)

Wrapper:

- `analysis-input2/001.0.bucketing/scripts/run_all.sh`

## Inputs

The input data for analysis-input2 can be stored either:

- under a per-run `Fastq/` subdirectory, or
- directly in the run directory (flat layout).

This is controlled by the sample sheet entries (see `metadata/samples-input2.tsv`),
which include `fastq_sample_id` to match the original FASTQ filename prefix when
it differs from the normalized `sample_id`.

## Outputs

- Per-run outputs under `output/<RUN_ID>/` (alignments, reports, buckets, etc.)
- Aggregated reports under `reports/`, including `reports/multiqc_report.html`
