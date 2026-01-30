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
- Config: `config/bowtie_vs_pave.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `analysis-input1/002.0.bowtie_vs_pave/scripts/run_all.sh` (all samples)
- `analysis-input1/002.0.bowtie_vs_pave/scripts/run.sh` (single sample pair)

## Inputs

- Reads directory: output of step 001 (`analysis-input1/001.0.centrifuge/output/`)
- PAVE reference inputs: configured in `config/bowtie_vs_pave.config`
- Lineage references: `refdata/hpv16_tree/lineages_ref_renamed.fasta` and
  `refdata/hpv18_tree/lineages_ref_renamed.fasta`

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
