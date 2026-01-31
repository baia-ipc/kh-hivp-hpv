# INVENTORY

## Analysis steps and scripts

- `analysis-input1/001.0.centrifuge/scripts`: run.sh, run_all.sh
- `analysis-input1/002.0.bowtie_vs_pave/scripts`: run.sh, run_all.sh
- `analysis-input1/003.0.virstrain/scripts`: run.sh, run_all.sh
- `analysis-input1/004.0.bowtie_vs_pave.E6/scripts`: run.sh, run_all.sh
- `analysis-input1/005.0.bowtie_vs_pave.E7/scripts`: run.sh, run_all.sh
- `analysis-input2/001.0.bucketing/scripts`: run_all.sh
- `analysis-input2/002.0.mapping_vs_pave/scripts`: run.sh, run_all.sh
- `analysis-input2/003.0.hpv16_tree/scripts`: run.sh, run_all.sh
- `analysis-input2/004.0.hpv18_tree/scripts`: run.sh, run_all.sh
- `analysis-input2/005.0.cambodia_snps/scripts`: run_all.sh
- `metadata/`: bucket_taxonomy_ids.tsv, hpv16_tree_bcf_run.txt, hpv16_tree_outgroups.txt, hpv18_lineage_refs.tsv, hpv18_tree_bcf_run.txt, hpv18_tree_outgroups.txt, hpv18_tree_samples.txt, samples-input1.tsv, samples-input2.tsv, pave_bucket_tid.txt
- `config/`: bowtie_vs_pave.config, bowtie_vs_pave.env.yml, bowtie_vs_pave.multiqc.yml, cambodia_snps.config, cambodia_snps.multiqc.yml, centrifuge_bucketing.config, centrifuge_bucketing.env.yml, centrifuge_bucketing.multiqc.yml, hpv16_tree.config, hpv18_tree.config, nextflow_java.env.yml, pave_e6.config, pave_e7.config, pave_gene_mapping.env.yml, pave_gene_mapping.multiqc.yml, phylo_tree.env.yml, phylo_tree.multiqc.yml, virstrain.config, virstrain.env.yml, virstrain.multiqc.env.yml, virstrain.multiqc.yml
- `scripts/`: aggregate_bucket_counts.py, aggregate_covstats.py, aggregate_depth_stats.py, aggregate_results.py, aggregate_top_strains.sh, assign_hpv18_lineages.py, assign_to_buckets.py, bucketize_fastq.py, build_centrifuge_db.sh, compare_lineage_snps.py, compare_query_snps_to_lineages.py, compare_query_snps_to_samples.py, compute_lca.py, covplot.py, covstats.py, csq_to_tsv.py, depth_stats.py, extract_country_sequences.py, fix_msa_formatting.py, gff3_to_csq_gff.py, hpv16_extract_lineages_fasta.sh, hpv16_prepare_samples.sh, hpv16_select_ncbi_genomes.sh, hpv18_extract_lineages_fasta.sh, hpv18_prepare_samples.sh, hpv18_select_ncbi_genomes.sh, identify_top_strains.py, lineage_snps_from_fasta.py, make_all_covplots.sh, rename_lineages.py, report_E6_E7_variants.sh, report_E6_E7_variant_effects.sh, summarize_hpv16_e6e7_variants.py
- `pipelines/`: bowtie_vs_pave.nf, cambodia_snps.nf, centrifuge_bucketing.nf, centrifuge_bucketing_all.nf, pave_gene_mapping.nf, phylo_tree.nf, virstrain.nf
- `refdata/`: curated reference data used by pipelines (pave reference, phylogenetic input sets)
- `reference-results/`: snapshot of outputs, reports, and indexes for regression checks (not tracked in git)

## Manual commands documented only in README.md

The step-level `analysis-input*/.../scripts/README.md` files are pointers only.
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
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \\
  refdata/hpv18_tree/selected.fasta refdata/hpv18_tree/selected_renamed.fasta
# edit refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then:
../../scripts/hpv18_select_ncbi_genomes.sh \\
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv refdata/hpv18_tree/HPV18-NCBIVirus.fasta \\
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \\
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \\
  refdata/hpv18_tree/selected.fasta refdata/hpv18_tree/selected_renamed.fasta
../../scripts/hpv18_prepare_samples.sh
```
