# Technical documentation

This directory contains technical documentation for the analysis steps in this
repository: what each step does, how it is implemented (pipelines + configs),
and where to find its inputs and outputs.

This documentation is intended for humans (e.g. lab / bioinformatics users).

To run the analyses, use the step wrapper scripts under `bin/`
(see the repository root `README.md`).

## Script reference

- Repository script reference: `docs/SCRIPTS.md`

## prelim_analysis

- Step 001 (Centrifuge bucketing): `docs/steps/prelim_analysis-001.0.centrifuge.md`
- Step 002 (Bowtie vs PAVE): `docs/steps/prelim_analysis-002.0.bowtie_vs_pave.md`
- Step 003 (VirStrain): `docs/steps/prelim_analysis-003.0.virstrain.md`
- Step 004 (PAVE E6 mapping): `docs/steps/prelim_analysis-004.0.bowtie_vs_pave.E6.md`
- Step 005 (PAVE E7 mapping): `docs/steps/prelim_analysis-005.0.bowtie_vs_pave.E7.md`

## targeted_analysis

- Step 001 (Centrifuge bucketing): `docs/steps/targeted_analysis-001.0.bucketing.md`
- Step 002 (Bowtie vs PAVE): `docs/steps/targeted_analysis-002.0.mapping_vs_pave.md`
- Step 003 (HPV16 tree): `docs/steps/targeted_analysis-003.0.hpv16_tree.md`
- Step 004 (HPV18 tree): `docs/steps/targeted_analysis-004.0.hpv18_tree.md`
- Step 005 (SNPs samples vs database): `docs/steps/targeted_analysis-005.0.snps_samples_vs_db.md`
