# analysis-input2 step 001: Centrifuge bucketing

## Overview

This step performs the same Centrifuge-based taxonomic bucketing as
analysis-input1 step 001 (human + RefSeq viral index), but using the
analysis-input2 sample list and input FASTQ layout.

## Implementation

- Pipeline: `pipelines/centrifuge_bucketing_all.nf`
- Config: `config/centrifuge_bucketing.config`
- Sample list: `metadata/samples-input2.tsv`

Wrapper:

- `analysis-input2/001.0.bucketing/scripts/run_all.sh`

## Inputs

The input data for analysis-input2 can be stored either:

- under a per-run `Fastq/` subdirectory, or
- directly in the run directory (flat layout).

This is controlled by the sample sheet entries (see `metadata/samples-input2.tsv`).

## Outputs

- Per-run outputs under `output/<RUN_ID>/` (alignments, reports, buckets, etc.)
- Aggregated reports under `reports/`, including `reports/multiqc_report.html`
