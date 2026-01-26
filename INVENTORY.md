# INVENTORY

## Analysis steps and scripts

- `analysis-input1/001.0.centrifuge/scripts`: run.sh, run_all.sh, README.md
- `analysis-input1/002.0.bowtie_vs_pave/scripts`: run.sh, run_all.sh, README.md
- `analysis-input1/003.0.virstrain/scripts`: run.sh, run_all.sh, README.md
- `analysis-input1/004.0.bowtie_vs_pave.E6/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, depth_stats.py, aggregate_depth_stats.py, run_postprocessing.sh, run_all_postprocessing.sh, run_aggregate_depth_stats.sh
- `analysis-input1/005.0.bowtie_vs_pave.E7/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, depth_stats.py, aggregate_depth_stats.py, run_postprocessing.sh, run_all_postprocessing.sh, run_aggregate_depth_stats.sh
- `analysis-input2/001.0.bucketing/scripts`: run_all.sh
- `analysis-input2/002.0.mapping_vs_pave/scripts`: run.sh, run_all.sh, README.md
- `analysis-input2/003.0.hpv16_tree/scripts`: 1_cat_all.sh, 2_run_mafft.sh, 3_run_trimal.sh, 4_run_iqtree.sh, extract_lineages_fasta.sh, rename_lineages.py, step4_select_ncbi_genomes.sh, step6_prepare_samples.sh, upcase.sh
- `analysis-input2/004.0.hpv18_tree/scripts`: 1_extract_lineages_ref_fasta.sh, 2_rename_lineage_ref_fasta.sh, 3_cat_all.sh, 4_run_mafft.sh, 5_run_trimal.sh, 6_run_iqtree.sh, assign_hpv18_lineages.py, rename_lineages.py, step4_select_ncbi_genomes.sh, step6_prepare_samples.sh
- `metadata/`: bucket_taxonomy_ids.tsv, samples-input1.tsv, samples-input2.tsv, pave_bucket_tid.txt
- `config/`: bowtie_vs_pave.config, bowtie_vs_pave.env.yml, centrifuge_bucketing.config, centrifuge_bucketing.env.yml, nextflow_java.env.yml, virstrain.config, virstrain.env.yml
- `scripts/`: aggregate_bucket_counts.py, aggregate_covstats.py, aggregate_results.py, aggregate_top_strains.sh, assign_to_buckets.py, bucketize_fastq.py, compute_lca.py, covplot.py, covstats.py, fix_msa_formatting.py, identify_top_strains.py, make_all_covplots.sh, report_E6_E7_variants.sh
- `pipelines/`: bowtie_vs_pave.nf, centrifuge_bucketing.sh, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf, virstrain.nf

## Manual commands documented only in README.md

- `analysis-input1/001.0.centrifuge/scripts/README.md`: no manual commands (docs only).
- `analysis-input1/003.0.virstrain/scripts/README.md`: Nextflow pipeline for VirStrain reports.
- `analysis-input1/002.0.bowtie_vs_pave/scripts/README.md`: Nextflow pipeline for bowtie vs PAVE mapping and reports.
- `analysis-input2/002.0.mapping_vs_pave/scripts/README.md`: same as above (Nextflow pipeline for bowtie vs PAVE mapping and reports).
- `analysis-input2/003.0.hpv16_tree/README.md`: manual downloads and prep steps for HPV16 lineages/NCBI data and sample consensus generation.
- `analysis-input2/004.0.hpv18_tree/README.md`: manual downloads and prep steps, including script-driven selection and consensus generation:

```bash
scripts/step4_select_ncbi_genomes.sh --init-selection
# edit input/HPV18-NCBIVirus.acc_country.selected.tsv, then:
scripts/step4_select_ncbi_genomes.sh
scripts/step6_prepare_samples.sh
```
