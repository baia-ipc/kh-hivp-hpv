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

- Step 01 (Centrifuge bucketing): `docs/steps/prelim_analysis-01.centrifuge.md`
- Step 02 (Bowtie vs PAVE): `docs/steps/prelim_analysis-02.bowtie_vs_pave.md`
- Step 05 (VirStrain, optional): `docs/steps/prelim_analysis-05.virstrain.md`

## targeted_analysis

- Step 01 (Centrifuge bucketing): `docs/steps/targeted_analysis-01.bucketing.md`
- Step 02 (Bowtie vs PAVE): `docs/steps/targeted_analysis-02.mapping_vs_pave.md`
- Step 03 (HPV16 tree): `docs/steps/targeted_analysis-03.hpv16_tree.md`
- Step 04 (HPV18 tree): `docs/steps/targeted_analysis-04.hpv18_tree.md`
- Step 05 (SNPs samples vs database): `docs/steps/targeted_analysis-05.snps_samples_vs_db.md`
