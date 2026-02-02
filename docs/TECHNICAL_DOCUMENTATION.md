# Technical documentation

This directory contains technical documentation for the analysis steps in this
repository: what each step does, how it is implemented (pipelines + configs),
and where to find its inputs and outputs.

This documentation is intended for humans (e.g. lab / bioinformatics users).

To run the analyses, use the step wrapper scripts under `bin/`
(see the repository root `README.md`).

## preliminary-analysis-all-patients

- Step 001 (Centrifuge bucketing): `docs/steps/preliminary-analysis-all-patients-001.0.centrifuge.md`
- Step 002 (Bowtie vs PAVE): `docs/steps/preliminary-analysis-all-patients-002.0.bowtie_vs_pave.md`
- Step 003 (VirStrain): `docs/steps/preliminary-analysis-all-patients-003.0.virstrain.md`
- Step 004 (PAVE E6 mapping): `docs/steps/preliminary-analysis-all-patients-004.0.bowtie_vs_pave.E6.md`
- Step 005 (PAVE E7 mapping): `docs/steps/preliminary-analysis-all-patients-005.0.bowtie_vs_pave.E7.md`

## targeted-analysis-hpv16-hpv18

- Step 001 (Centrifuge bucketing): `docs/steps/targeted-analysis-hpv16-hpv18-001.0.bucketing.md`
- Step 002 (Bowtie vs PAVE): `docs/steps/targeted-analysis-hpv16-hpv18-002.0.mapping_vs_pave.md`
- Step 003 (HPV16 tree): `docs/steps/targeted-analysis-hpv16-hpv18-003.0.hpv16_tree.md`
- Step 004 (HPV18 tree): `docs/steps/targeted-analysis-hpv16-hpv18-004.0.hpv18_tree.md`
- Step 005 (SNPs samples vs database): `docs/steps/targeted-analysis-hpv16-hpv18-005.0.snps_samples_vs_db.md`
