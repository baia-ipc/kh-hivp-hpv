# analysis-input1 step 002: Bowtie vs PAVE

## Overview

This step maps bucketed reads to a PAVE reference using Bowtie2, summarizes
mapping by strain, computes coverage statistics, performs variant calling, and
annotates E6/E7 variants with amino‑acid consequences. It also compares sample
E6/E7 SNPs against lineage‑defining SNPs derived from HPV16/HPV18 lineage
reference genomes.

## Implementation

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/bowtie_vs_pave.nf`
- User config: `config/general.config`
- Step path config: `bin/config/analysis-input1_002.bowtie_vs_pave.config` (internal defaults)
- Technical config: `pipelines/config/common.technical.config` + `pipelines/config/bowtie_vs_pave.technical.config`
- Bucket selection: `params.bucket_tid` in `pipelines/config/bowtie_vs_pave.technical.config`

Wrappers:

- `bin/002.0.bowtie_vs_pave.run.sh` (all samples)
- `bin/sample/002.0.bowtie_vs_pave.run_sample.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`analysis-input1/001.0.centrifuge/output/`)
- PAVE reference inputs (wired via `pipelines/config/bowtie_vs_pave.technical.config`):
  - Reference FASTA: `refdata/raw/pave/pave_hsa.fas`
  - GFF3 directory: `refdata/raw/pave/gff3`
  - BED directory: `refdata/derived/pave/bed` (generated from GFF3 with `scripts/gff3_to_bed.run_all.sh`)
  - Feature tables (derived): `refdata/derived/pave/features_tsv` (generated from GFF3 with `scripts/gff3_to_features_tsv.run_all.sh`)
- Lineage references: `refdata/derived/hpv16_tree/lineages_ref_renamed.fasta` and
  `refdata/derived/hpv18_tree/lineages_ref_renamed.fasta`

## Outputs

Per run (`output/<RUN_ID>/`):

- per-sample mapping artifacts (SAM/BAM, indexes, and intermediate files)
- per-sample variant calling artifacts (BCF and derived summaries)

Aggregated, step-level reports (`reports/`):

- mapping and strain summaries
- coverage/variant summaries
- E6/E7 variant effects (amino‑acid consequences)
- Lineage SNP comparison table (sample SNPs annotated with lineage matches)
- MultiQC report: `reports/multiqc_report.html`
