# INVENTORY

## Analysis steps and scripts

- `analysis-1/steps/001.0.centrifuge/scripts`: run.sh, run_all.sh, README.md
- `analysis-1/steps/002.0.bowtie_vs_pave/scripts`: run.sh, run_all.sh, create-index.sh, README.md
- `analysis-1/steps/002.0.bowtie_vs_pave/scripts/dev`: run_postprocessing.sh, run_all_postprocessing.sh, run_aggregate_depth_stats.sh, depth_stats.py, aggregate_depth_stats.py
- `analysis-1/steps/003.0.virstrain/scripts`: run.sh, run_all.sh, create-index.sh, fix_msa_formatting.py, aggregate_results.py, README.md
- `analysis-2/steps/001.0.centrifuge/scripts`: run.sh, run_all.sh, compute_lca.py, assign_to_buckets.py, bucketize_fastq.py, aggregate_bucket_counts.py, README.md
- `analysis-2/steps/002.0.bowtie_vs_pave/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, covstats.py, covplot.py, aggregate_covstats.py, make_all_covplots.sh, report_E6_E7_variants.sh, README.md
- `analysis-2/steps/003.0.bowtie_vs_pave.E6/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, depth_stats.py, aggregate_depth_stats.py, run_postprocessing.sh, run_all_postprocessing.sh, run_aggregate_depth_stats.sh
- `analysis-2/steps/004.0.bowtie_vs_pave.E7/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, depth_stats.py, aggregate_depth_stats.py, run_postprocessing.sh, run_all_postprocessing.sh, run_aggregate_depth_stats.sh
- `analysis-3/steps/001.0.bucketing/scripts`: run_all.sh
- `analysis-3/steps/002.0.mapping_vs_pave/scripts`: run.sh, run_all.sh, create-index.sh, identify_top_strains.py, covstats.py, covplot.py, aggregate_covstats.py, make_all_covplots.sh, report_E6_E7_variants.sh, README.md
- `analysis-3/steps/003.0.hpv16_tree/scripts`: 1_cat_all.sh, 2_run_mafft.sh, 3_run_trimal.sh, 4_run_iqtree.sh, extract_lineages_fasta.sh, rename_lineages.py, step4_select_ncbi_genomes.sh, step6_prepare_samples.sh, upcase.sh
- `analysis-3/steps/004.0.hpv18_tree/scripts`: 1_extract_lineages_ref_fasta.sh, 2_rename_lineage_ref_fasta.sh, 3_cat_all.sh, 4_run_mafft.sh, 5_run_trimal.sh, 6_run_iqtree.sh, assign_hpv18_lineages.py, rename_lineages.py, step4_select_ncbi_genomes.sh, step6_prepare_samples.sh
- `scripts/`: bucketize_fastq.py, assign_to_buckets.py, compute_lca.py, aggregate_bucket_counts.py, identify_top_strains.py
- `pipelines/`: centrifuge_bucketing.sh, centrifuge_bucketing.nf, centrifuge_bucketing.config

## Manual commands documented only in README.md

- `analysis-1/steps/001.0.centrifuge/scripts/README.md`: no manual commands (docs only).
- `analysis-1/steps/003.0.virstrain/scripts/README.md`: no manual commands (docs only).
- `analysis-1/steps/002.0.bowtie_vs_pave/scripts/README.md`: create bowtie2 index; align with `bowtie --all`; count with `samtools idxstats`; run rough strain assignment script.
- `analysis-2/steps/002.0.bowtie_vs_pave/scripts/README.md`: same as above (create index, bowtie --all, samtools idxstats, rough strain assignment).
- `analysis-3/steps/002.0.mapping_vs_pave/scripts/README.md`: same as above (create index, bowtie --all, samtools idxstats, rough strain assignment).
- `analysis-3/steps/003.0.hpv16_tree/README.md`: manual downloads and prep steps for HPV16 lineages/NCBI data and sample consensus generation.
- `analysis-3/steps/004.0.hpv18_tree/README.md`: manual downloads and prep steps, including script-driven selection and consensus generation:

```bash
scripts/step4_select_ncbi_genomes.sh --init-selection
# edit input/HPV18-NCBIVirus.acc_country.selected.tsv, then:
scripts/step4_select_ncbi_genomes.sh
scripts/step6_prepare_samples.sh
```
