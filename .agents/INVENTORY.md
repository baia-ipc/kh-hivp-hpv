# INVENTORY

## Analysis steps and scripts

- `bin/`: analysis-level runners (`prelim_analysis.run.sh`, `targeted_analysis.run.sh`) plus step runners under `bin/prelim_analysis.steps/` and `bin/targeted_analysis.steps/` with single-sample wrappers under their `single_sample/` subdirectories
- `metadata/`: bucket_taxonomy_ids.tsv, hpv16_tree_outgroups.txt, hpv18_lineage_refs.tsv, hpv18_tree_outgroups.txt, samples-input1.tsv, samples-input2.tsv
- `config/`: user.config
- `config/analyses/`: prelim_analysis.config, targeted_analysis.config
- `config/pipelines/`: bowtie_vs_pave.config, database_snps.config, centrifuge_bucketing.config, common.config, pave_gene_mapping.config, phylo_tree.config, phylo_tree.hpv16.config, phylo_tree.hpv18.config, virstrain.config
- `pipelines/multiqc/`: bowtie_vs_pave.multiqc.yml, database_snps.multiqc.yml, centrifuge_bucketing.multiqc.yml, pave_gene_mapping.multiqc.yml, phylo_tree.multiqc.yml, virstrain.multiqc.yml
- `pipelines/conda_env/`: nextflow_java.env.yml, pipeline.env.yml, virstrain.env.yml
- `input_reads/`: symlinks or folders pointing to raw FASTQ data (not tracked in git)
- `scripts/`: grouped by concern in subdirectories
  - `scripts/taxonomy_assignment/`: build_centrifuge_db.sh, compute_lca.py, assign_to_buckets.py, bucketize_fastq.py, aggregate_bucket_counts.py
  - `scripts/top_strains/`: identify_top_strains.py, aggregate_top_strains.sh
  - `scripts/coverage/`: covstats.py, depth_stats.py, aggregate_covstats.py, aggregate_depth_stats.py, covplot.py, make_all_covplots.sh
  - `scripts/variants/`: report_E6_E7_variants.sh, report_E6_E7_variant_effects.sh, csq_to_tsv.py, lineage_snps_from_fasta.py, compare_lineage_snps.py, compare_query_snps_to_lineages.py, compare_query_snps_to_samples.py, compare_samples_to_query_snps.py, compare_sample_snp_sets_to_lineages.py, compare_sample_snp_sets_to_database.py, summarize_hpv16_e6e7_variants_database.py
  - `scripts/pave/`: gff3_to_features_tsv.py, gff3_to_features_tsv.run_all.sh, gff3_to_bed.py, gff3_to_bed.run_all.sh, gff3_to_csq_gff.py, make_features_plot.py, make_features_plot.run_all.sh, make_tabix_dir.sh
  - `scripts/virstrain/`: aggregate_virstrain_results.py
  - `scripts/phylo_tree/`: hpv16_select_ncbi_genomes.sh, hpv18_select_ncbi_genomes.sh, hpv16_extract_lineages_fasta.sh, hpv18_extract_lineages_fasta.sh, rename_lineages.py, fix_msa_formatting.py, assign_hpv18_lineages.py, hpv16_prepare_samples.sh, hpv18_prepare_samples.sh, extract_country_sequences.py
- `pipelines/`: bowtie_vs_pave.nf, database_snps.nf, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf, pave_gene_mapping.nf, phylo_tree.nf, virstrain.nf
- `refdata/`: external reference inputs used by pipelines (PAVE reference, NCBI downloads)
- `derived_data/refdata/`: derived reference assets (feature tables, curated tree inputs)
- `derived_data/indices/`: shared Bowtie/VirStrain indices (bowtie_vs_pave and preliminary/virstrain)
- `reference-results/`: snapshot of outputs, reports, and indexes for regression checks (not tracked in git)

## Manual commands documented only in README.md

Technical documentation is maintained under `docs/`.

Step documentation index: `docs/TECHNICAL_DOCUMENTATION.md`

The only steps that typically require manual preparation are the phylogenetic
tree steps (inputs under `refdata/`). The human-facing preparation commands are
documented in the repository root `README.md`.

Example (HPV18 selection workflow):

```bash
../../scripts/phylo_tree/hpv18_select_ncbi_genomes.sh --init-selection \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  derived_data/refdata/hpv18_tree/selected.fasta derived_data/refdata/hpv18_tree/selected_renamed.fasta
# edit derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then:
../../scripts/phylo_tree/hpv18_select_ncbi_genomes.sh \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  derived_data/refdata/hpv18_tree/selected.fasta derived_data/refdata/hpv18_tree/selected_renamed.fasta
../../scripts/phylo_tree/hpv18_prepare_samples.sh
```
