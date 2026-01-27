# WORKFLOWS

Ordered view of steps and dependencies across analyses (happy path).

Rules:
- Do not add command lines here (put them in `OPERATIONS.md`).
- Do not describe tools/config locations here beyond what is needed for dependencies (put full catalog info in `SKILLS.md`).

## Workflow: analysis-input1

1) Centrifuge bucketing (Nextflow)
   - Pipeline: `pipelines/centrifuge_bucketing_all.nf`
   - Samples: `metadata/samples-input1.tsv`
   - Outputs: `analysis-input1/001.0.centrifuge/{output,reports}`

2) Bowtie vs PAVE mapping
   - Pipeline: `pipelines/bowtie_vs_pave.nf`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input1/002.0.bowtie_vs_pave/{output,reports}`

3) VirStrain reports
   - Pipeline: `pipelines/virstrain.nf`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input1/003.0.virstrain/{output,reports}`

4) E6/E7 sub-analyses
   - E6 (Nextflow): `pipelines/pave_gene_mapping.nf`
   - E7 (Nextflow): `pipelines/pave_gene_mapping.nf`

## Workflow: analysis-input2 (mapping)

1) Bucketing
   - Pipeline: `pipelines/centrifuge_bucketing_all.nf`
   - Samples: `metadata/samples-input2.tsv`
   - Outputs: `analysis-input2/001.0.bucketing/{output,reports}`

2) Mapping vs PAVE
   - Pipeline: `pipelines/bowtie_vs_pave.nf`
   - Inputs: buckets from step 001
   - Outputs: `analysis-input2/002.0.mapping_vs_pave/{output,reports}`

## Workflow: phylogenetic trees

- HPV16 (Nextflow): `pipelines/phylo_tree.nf`
- HPV18 (Nextflow): `pipelines/phylo_tree.nf`
- Inputs: mapping outputs plus curated references in each step's `input/` directory.
