# INVENTORY

## Analysis steps and scripts

- `bin/`: analysis-level runners (preliminary-analysis-all-patients.run.sh, targeted-analysis-hpv16-hpv18.run.sh) plus step runners under `bin/preliminary-analysis-all-patients.steps/` and `bin/targeted-analysis-hpv16-hpv18.steps/` with single-sample wrappers under their `single_sample/` subdirectories
- `metadata/`: bucket_taxonomy_ids.tsv, hpv16_tree_outgroups.txt, hpv18_lineage_refs.tsv, hpv18_tree_outgroups.txt, samples-input1.tsv, samples-input2.tsv
- `config/`: user.config
- `bin/config/`: preliminary-analysis-all-patients.config, targeted-analysis-hpv16-hpv18.config
- `config/pipelines/`: bowtie_vs_pave.config, cambodia_snps.config, centrifuge_bucketing.config, common.config, pave_gene_mapping.config, phylo_tree.config, phylo_tree.hpv16.config, phylo_tree.hpv18.config, virstrain.config
- `pipelines/multiqc/`: bowtie_vs_pave.multiqc.yml, cambodia_snps.multiqc.yml, centrifuge_bucketing.multiqc.yml, pave_gene_mapping.multiqc.yml, phylo_tree.multiqc.yml, virstrain.multiqc.yml
- `pipelines/conda_env/`: nextflow_java.env.yml, pipeline.env.yml, virstrain.env.yml
- `scripts/`: aggregate_bucket_counts.py, aggregate_covstats.py, aggregate_depth_stats.py, aggregate_results.py, aggregate_top_strains.sh, assign_hpv18_lineages.py, assign_to_buckets.py, bucketize_fastq.py, build_centrifuge_db.sh, compare_lineage_snps.py, compare_query_snps_to_lineages.py, compare_query_snps_to_samples.py, compare_sample_snp_sets_to_cambodia.py, compare_sample_snp_sets_to_lineages.py, compare_samples_to_query_snps.py, compute_lca.py, covplot.py, covstats.py, csq_to_tsv.py, depth_stats.py, extract_country_sequences.py, fix_msa_formatting.py, gff3_to_bed.py, gff3_to_bed.run_all.sh, gff3_to_csq_gff.py, gff3_to_features_tsv.py, gff3_to_features_tsv.run_all.sh, hpv16_extract_lineages_fasta.sh, hpv16_prepare_samples.sh, hpv16_select_ncbi_genomes.sh, hpv18_extract_lineages_fasta.sh, hpv18_prepare_samples.sh, hpv18_select_ncbi_genomes.sh, identify_top_strains.py, lineage_snps_from_fasta.py, make_all_covplots.sh, make_features_plot.py, make_features_plot.run_all.sh, make_tabix_dir.sh, rename_lineages.py, report_E6_E7_variant_effects.sh, report_E6_E7_variants.sh, summarize_hpv16_e6e7_variants.py
- `pipelines/`: bowtie_vs_pave.nf, cambodia_snps.nf, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf, pave_gene_mapping.nf, phylo_tree.nf, virstrain.nf
- `refdata/`: external reference inputs used by pipelines (PAVE reference, NCBI downloads)
- `intermediate_files/refdata/`: derived reference assets (feature tables, curated tree inputs)
- `intermediate_files/indices/`: bowtie/virstrain indices
- `reference-results/`: snapshot of outputs, reports, and indexes for regression checks (not tracked in git)

## Manual commands documented only in README.md

Technical documentation is maintained under `docs/`.

Step documentation index: `docs/TECHNICAL_DOCUMENTATION.md`

The only steps that typically require manual preparation are the phylogenetic
tree steps (inputs under `refdata/`). The human-facing preparation commands are
documented in the repository root `README.md`.

Example (HPV18 selection workflow):

```bash
../../scripts/hpv18_select_ncbi_genomes.sh --init-selection \\
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv refdata/hpv18_tree/HPV18-NCBIVirus.fasta \\
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \\
  intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \\
  intermediate_files/refdata/hpv18_tree/selected.fasta intermediate_files/refdata/hpv18_tree/selected_renamed.fasta
# edit intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then:
../../scripts/hpv18_select_ncbi_genomes.sh \\
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv refdata/hpv18_tree/HPV18-NCBIVirus.fasta \\
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \\
  intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \\
  intermediate_files/refdata/hpv18_tree/selected.fasta intermediate_files/refdata/hpv18_tree/selected_renamed.fasta
../../scripts/hpv18_prepare_samples.sh
```
