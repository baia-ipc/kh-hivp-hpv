# INVENTORY

## Analysis steps and scripts

- `bin/`: analysis-level runners (`prelim_analysis.run.sh`, `targeted_analysis.run.sh`), a generic step runner (`bin/run_step.py`), plus step runners under `bin/prelim_analysis.steps/` and `bin/targeted_analysis.steps/` with single-sample wrappers under their `single_sample/` subdirectories
- `metadata/`: bucketing/, cohort/, hpv16_tree/, hpv18_tree/, seq_samples/
- `config/`: user.config
- `config/analyses/`: prelim_analysis.config, targeted_analysis.config
- `config/steps/`: JSON configs for per-step wrapper parameters (pipeline, configs, profile, flags)
- `config/pipelines/`: bowtie_vs_pave.config, centrifuge_bucketing.config, common.config, pave_gene_mapping.config, phylo_tree.config, phylo_tree.hpv16.config, phylo_tree.hpv18.config, variant_analysis.config, virstrain.config
- `pipelines/multiqc/`: bowtie_vs_pave.multiqc.yml, centrifuge_bucketing.multiqc.yml, pave_gene_mapping.multiqc.yml, phylo_tree.multiqc.yml, variant_analysis.multiqc.yml, variant_analysis_db.multiqc.yml, virstrain.multiqc.yml
- `pipelines/conda_env/`: nextflow_java.env.yml, pipeline.env.yml, virstrain.env.yml
- `input_reads/`: symlinks or folders pointing to raw FASTQ data (not tracked in git)
- `scripts/`: grouped by concern in subdirectories
  - `scripts/taxonomy_assignment/`: build_centrifuge_db.sh, compute_lca.py, assign_to_buckets.py, bucketize_fastq.py, aggregate_bucket_counts.py, prepare_centrifuge_multiqc_inputs.py
  - `scripts/top_strains/`: identify_top_strains.py, aggregate_top_strains.sh
  - `scripts/coverage/`: covstats.py, depth_stats.py, aggregate_covstats.py, aggregate_depth_stats.py, covplot.py, make_all_covplots.sh, strain_assignment_coverage_report.py, prepare_bowtie_multiqc_inputs.py, prepare_pave_multiqc_inputs.py
  - `scripts/variants/`: report_E6_E7_variants.sh, report_E6_E7_variant_effects.sh, csq_to_tsv.py, lineage_snps_from_fasta.py, compare_lineage_snps.py, compare_query_snps_to_lineages.py, compare_query_snps_to_samples.py, compare_samples_to_query_snps.py, compare_sample_snp_sets_to_lineages.py, compare_sample_snp_sets_to_database.py, summarize_hpv16_e6e7_variants_database.py, prepare_database_multiqc_tables.py, prepare_variant_multiqc_inputs.py
  - `scripts/pave/`: gff3_to_features_tsv.py, gff3_to_features_tsv.run_all.sh, gff3_to_bed.py, gff3_to_bed.run_all.sh, gff3_to_csq_gff.py, make_features_plot.py, make_features_plot.run_all.sh, make_tabix_dir.sh
  - `scripts/virstrain/`: aggregate_virstrain_results.py, prepare_virstrain_multiqc_inputs.py
  - `scripts/phylo_tree/`: select_ncbi_genomes.sh, extract_lineages_fasta.sh, prepare_samples.sh, rename_lineages.py, fix_msa_formatting.py, assign_lineages.py, extract_country_sequences.py, build_tree_selection_tsv.py, render_tree_svg.py, compute_tree_stats.py
- `pipelines/`: bowtie_vs_pave.nf, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf, pave_gene_mapping.nf, phylo_tree.nf, variant_analysis.nf, virstrain.nf
- `refdata/`: external reference inputs used by pipelines (PAVE reference, NCBI downloads)
- `derived_data/refdata/`: derived reference assets (auto-generated; not tracked in git)
- `derived_data/indices/`: shared Bowtie/VirStrain indices (auto-generated; not tracked in git)
- `outs/`: analysis outputs and non‑MultiQC reports (not tracked in git)
- `results/`: curated copies of key outputs for sharing or review (tracked in git)
- `reference-results/`: snapshot of outputs, reports, and indexes for regression checks (not tracked in git)

## Documentation index

Technical documentation is maintained under `docs/`.

Step documentation index: `docs/TECHNICAL_DOCUMENTATION.md`

Tree reference preparation guidance lives in the user manual:
`docs/USER_MANUAL.md` (Phylogenetic tree inputs section).
