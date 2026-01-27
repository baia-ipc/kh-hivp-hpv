# WORKFLOWS

This file describes the standard workflows and where inputs, outputs, and reports live.

## Conventions

- Configuration files live in `config/`.
- Sample lists and other hardcoded data live in `metadata/`.
- Each step writes to `output/` (per-sample artifacts) and `reports/` (summaries).
- Update `CONTENTS.md` and `INVENTORY.md` after directory reordering.

## Workflow: analysis-input1

1) Centrifuge bucketing (Nextflow)
   - Pipeline: `pipelines/centrifuge_bucketing_all.nf`
   - Samples: `metadata/samples-input1.tsv`
   - Outputs: `analysis-input1/001.0.centrifuge/{output,reports}`

2) Bowtie vs PAVE mapping
   - Pipeline: `pipelines/bowtie_vs_pave.nf`
   - Wrapper: `analysis-input1/002.0.bowtie_vs_pave/scripts/run_all.sh`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input1/002.0.bowtie_vs_pave/{output,reports}`

3) VirStrain reports
   - Pipeline: `pipelines/virstrain.nf`
   - Wrapper: `analysis-input1/003.0.virstrain/scripts/run_all.sh`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input1/003.0.virstrain/{output,reports}`

4) E6/E7 sub-analyses
   - E6 (Nextflow): `pipelines/pave_gene_mapping.nf` via `analysis-input1/004.0.bowtie_vs_pave.E6/scripts/run_all.sh`
   - E7 (legacy): `analysis-input1/005.0.bowtie_vs_pave.E7/scripts/run_all.sh`

## Workflow: analysis-input2 (mapping)

1) Bucketing
   - Script: `analysis-input2/001.0.bucketing/scripts/run_all.sh`
   - Outputs: `analysis-input2/001.0.bucketing/{output,reports}`

2) Mapping vs PAVE
   - Pipeline: `pipelines/bowtie_vs_pave.nf`
   - Wrapper: `analysis-input2/002.0.mapping_vs_pave/scripts/run_all.sh`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input2/002.0.mapping_vs_pave/{output,reports}`

## Workflow: phylogenetic trees

- HPV16: `analysis-input2/003.0.hpv16_tree`
- HPV18: `analysis-input2/004.0.hpv18_tree`
- Inputs: mapping outputs plus curated references in each step's `input/` directory.

## Reruns and resume

- Nextflow: pass `-resume` after fixing inputs or configuration.
- Scripts: remove step outputs if a full rerun is required.

## Data updates

- Update sample lists in `metadata/`.
- Update indices under step `index/` or shared `refdata/` when applicable.
