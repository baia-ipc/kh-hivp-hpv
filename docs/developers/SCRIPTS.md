# Scripts documentation

This document describes each script in `scripts/`, its purpose, where it is
used in the pipeline (if applicable), and the key parameters or environment
inputs that affect behavior. Scripts are grouped in concern-based
subdirectories that mirror the section headers below.

## Centrifuge bucketing and taxonomy processing

### `scripts/taxonomy_assignment/build_centrifuge_db.sh`
Purpose: Build a Centrifuge index (human + RefSeq domains) plus taxonomy data
used by the bucketing pipeline. This is a manual preparation step that
produces the `params.index` and `params.taxdump` inputs consumed by the
bucketing workflows.
Key parameters:
- `--outdir`: output root that will hold taxonomy, library, and index files.
- `--taxonomy-date`: optional date suffix for taxonomy dir naming.
- `--index-name`: index base name (final index path is `<outdir>/<index-name>`).
- `--refseq-domains`: comma-separated RefSeq domains to download.
- `--threads`: number of build threads (defaults to `$THREADS` or 24).

### `scripts/taxonomy_assignment/compute_lca.py`
Purpose: Compute the lowest common ancestor (LCA) for each read in Centrifuge
TSV output. This collapses multiple taxonomic hits to a single assignment that
is used by the bucketing pipeline.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp` file.
- `<centrifuge_tsv>`: Centrifuge tabular output file.
- `<outfile>`: output TSV with read IDs and LCA tax IDs.

### `scripts/taxonomy_assignment/assign_to_buckets.py`
Purpose: Assign each taxonomic ID in a TSV to a bucket head (taxonomy node).
This is the core step for bucketing reads into curated taxonomic categories.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp`.
- `<tsv_file>` / `<column>`: input TSV and 1-based taxid column.
- `<bucket_heads>...`: list of bucket head taxids.
- `<outfile>`: output TSV with appended bucket column.

### `scripts/taxonomy_assignment/bucketize_fastq.py`
Purpose: Split FASTQ reads into per-bucket FASTQ files using the bucket
assignment TSV. Used to create bucket-specific readsets for downstream steps.
Key parameters:
- `<tsv_file>`: assignment table containing read IDs and bucket IDs.
- `<read_id_col>` / `<bucket_id_col>`: 1-based columns for read and bucket IDs.
- `<fastq_file>`: input FASTQ (plain or gzip).
- `<bucket_basename>`: output prefix for `*.{bucket}.fastq.gz` files.
- `--skip`: bucket IDs to exclude from splitting.

### `scripts/taxonomy_assignment/aggregate_bucket_counts.py`
Purpose: Aggregate per-sample bucket assignment counts into run-level tables
used by bucketing reports and MultiQC. Generates absolute and relative count
summaries.
Key parameters:
- `<bucket_ids_table>`: taxonomy bucket ID → name mapping (drives column order).
- `<root>`: bucketing output root containing per-run `bucket_sizes/` tables.
- `<outputdir>`: output directory for aggregate tables.
- `--skip`: bucket IDs to exclude from aggregation (e.g., human).
- `--no-abs` / `--no-rel`: disable one of the tables.
- `--abs-fname` / `--rel-fname`: override output filenames.

### `scripts/taxonomy_assignment/prepare_centrifuge_multiqc_inputs.py`
Purpose: Reformat bucketing count tables into MultiQC-ready TSVs with a Sample
ID column.
Key parameters:
- `--absolute`: input absolute counts TSV.
- `--absolute-out`: output MultiQC TSV.
- `--relative`: input relative counts TSV.
- `--relative-out`: output MultiQC TSV.
- `--relative-wo-human`: input relative counts without human TSV.
- `--relative-wo-human-out`: output MultiQC TSV.

## Bowtie vs PaVE mapping, coverage, and variant calling

### `scripts/top_strains/identify_top_strains.py`
Purpose: Parse `samtools idxstats` output to identify top HPV strains per
sample based on relative abundance and minimum read count. Used in the mapping
pipeline and reporting.
Key parameters:
- `<idxstats_output.txt>`: input from `samtools idxstats`.
- `--threshold`: ratio to top strain required to be considered "top".
- `--mincount`: minimum reads required to be considered.

### `scripts/top_strains/aggregate_top_strains.sh`
Purpose: Aggregate per-sample `.top_strains` files across runs into a single
TSV used by mapping-vs-PaVE reports and MultiQC.
Key parameters:
- `<output_root>`: root containing per-run `.top_strains` files.
- `<output_file>`: aggregated TSV output path.

### `scripts/coverage/covstats.py`
Purpose: Compute per-strain coverage depth and breadth from `samtools depth -aa`.
Optionally computes coverage over features (E6/E7) using feature TSVs.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with depth stats.
- `<tsvfiles>`: optional directory of feature TSVs (`<strain>REF.tsv`).
- `--features`: comma-separated feature names (default `E6,E7`).

### `scripts/coverage/depth_stats.py`
Purpose: Compute mean depth and breadth per strain from a depth file. Used
when a simpler depth summary is sufficient.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with mean depth and breadth.

### `scripts/coverage/aggregate_covstats.py`
Purpose: Aggregate per-sample `*.depth.stats` files into a combined table
filtered by minimum depth/breadth thresholds for reporting and MultiQC.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/coverage/aggregate_depth_stats.py`
Purpose: Aggregate simple depth statistics across runs, filtering by mean depth
and breadth thresholds.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/coverage/covplot.py`
Purpose: Produce coverage plots with gene features annotated from TSV files.
Used for manual QC/visualization of coverage profiles.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<strain_name>`: strain to select from depth file.
- `<tsv_file>`: feature TSV (gene name, start, end).
- `<output_file>`: plot output (png/pdf).

### `scripts/coverage/make_all_covplots.sh`
Purpose: Batch-generate coverage plots for all samples listed in a covstats
summary file.
Key parameters:
- `<cov_stats.tsv>`: aggregated coverage stats (run/sample/strain list).
- `<depth_root>`: root containing per-run depth files.
- `<features_tsv_dir>`: directory of feature TSVs.
- `[plots_outdir]`: optional output directory.

### `scripts/coverage/strain_assignment_coverage_report.py`
Purpose: Combine strain assignment and coverage stats with cohort metadata for
reporting and MultiQC.
Key parameters:
- `<strains.tsv>`: aggregated strain calls (run/sample/strain).
- `<cov_stats.tsv>`: aggregated coverage stats.
- `<patients_metadata.tsv>`: cohort metadata table.
- `<genexpert_results.tsv>`: GeneXpert summary table.
- `<output_tsv>`: output report TSV.

### `scripts/coverage/prepare_bowtie_multiqc_inputs.py`
Purpose: Reformat bowtie-vs-PAVE coverage tables into MultiQC-ready TSVs with
sample IDs.
Key parameters:
- `--strains` / `--strains-out`: strains input/output TSVs.
- `--cov-stats` / `--cov-stats-out`: coverage stats input/output TSVs.
- `--cov-stats-filtered` / `--cov-stats-filtered-out`: filtered coverage stats input/output TSVs.
- `--coverage` / `--coverage-out`: strain assignment coverage input/output TSVs.

### `scripts/coverage/prepare_pave_multiqc_inputs.py`
Purpose: Reformat PAVE gene mapping depth tables into MultiQC-ready TSVs with
sample IDs.
Key parameters:
- `--strains` / `--strains-out`: strains input/output TSVs.
- `--depth-unfiltered` / `--depth-unfiltered-out`: unfiltered depth stats input/output TSVs.
- `--depth-filtered` / `--depth-filtered-out`: filtered depth stats input/output TSVs.

### `scripts/variants/report_E6_E7_variants.sh`
Purpose: Extract E6/E7 variants from per-sample BCFs using BED intervals. Used
by the bowtie-vs-PaVE pipeline to build variants tables.
Key parameters:
- `<outputdir>`: root containing `run_id/*.bcf.gz` files.
- `<bed_dir>`: directory with `pave_hsa.E6.bed` and `pave_hsa.E7.bed`.

### `scripts/variants/report_E6_E7_variant_effects.sh`
Purpose: Use bcftools csq to annotate E6/E7 variants and emit a TSV with
consequences via `csq_to_tsv.py`.
Key parameters:
- `<outputdir>`: root containing per-run BCFs.
- `<bed_dir>`: directory with E6/E7 BED files.
- `<gff3_dir>`: directory of PaVE GFF3s.
- `<ref_fasta>`: reference FASTA used for csq annotations.

### `scripts/variants/csq_to_tsv.py`
Purpose: Convert bcftools csq output (read from stdin) to TSV rows with
run/sample/gene fields, one row per consequence.
Key parameters:
- `--run`: run ID label to include in the TSV.
- `--sample`: sample ID label to include.
- `--gene`: gene label (E6/E7).
- `--tag`: INFO tag containing csq annotations (default `BCSQ`).
- `--no-header`: suppress header emission (used for multi-file concatenation).

### `scripts/variants/prepare_variant_multiqc_inputs.py`
Purpose: Reformat E6/E7 variant tables into MultiQC-ready TSVs with stable
sample IDs and decoded metadata fields.
Key parameters:
- `--variants` / `--variants-out`: E6/E7 variants input/output TSVs.
- `--variant-effects` / `--variant-effects-out`: variant effects input/output TSVs.
- `--lineage-compare` / `--lineage-compare-out`: optional lineage comparison input/output TSVs.

### `scripts/variants/prepare_database_multiqc_tables.py`
Purpose: Reformat database comparison tables into MultiQC-ready TSVs with
stable row IDs and pass-through summary tables.
Key parameters:
- `--database-snps` / `--database-snps-out`: database SNPs input/output TSVs.
- `--database-lineage-comparison` / `--database-lineage-comparison-out`: lineage comparison input/output TSVs.
- `--database-sample-comparison` / `--database-sample-comparison-out`: sample comparison input/output TSVs.
- `--samples-vs-database` / `--samples-vs-database-out`: samples vs database input/output TSVs.
- `--samples-vs-database-sets` / `--samples-vs-database-sets-out`: SNP set comparison input/output TSVs.
- `--samples-vs-lineage-sets` / `--samples-vs-lineage-sets-out`: lineage SNP set comparison input/output TSVs.
- `--hpv16-e6e7-summary` / `--hpv16-e6e7-summary-out`: HPV16 E6/E7 summary input/output TSVs.

### `scripts/variants/reorder_multiqc_sections.py`
Purpose: Reorder selected sections in a generated MultiQC HTML report so
specified modules/nav entries are moved to the bottom (used to place General
Stats, Bcftools, and Samtools at the end of variant-analysis reports).
Key parameters:
- `--report`: MultiQC HTML report path to rewrite in place.
- `--section-id`: repeatable section `div` IDs to move (e.g. `general_stats`).
- `--nav-anchor`: repeatable navigation anchors (without `#`) to move to the
  bottom of the sidebar navigation.

## PaVE reference feature derivation

### `scripts/pave/gff3_to_features_tsv.py`
Purpose: Convert a single PaVE GFF3 file into a TSV of gene/regulatory
features for coverage stats and plotting.
Key parameters:
- `<gff3_file>`: PaVE GFF3 file.
- `--verbose` / `--quiet`: logging control.

### `scripts/pave/gff3_to_features_tsv.run_all.sh`
Purpose: Batch-run `gff3_to_features_tsv.py` over a directory of GFF3s.
Key parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for TSVs.

### `scripts/pave/gff3_to_bed.py`
Purpose: Convert a PaVE GFF3 into a BED file (gene/regulatory regions). These
BEDs are used to filter E6/E7 variants and lineage SNP calling.
Key parameters:
- `<gff3_file>`: PaVE GFF3 file.
- `--verbose` / `--quiet`: logging control.

### `scripts/pave/gff3_to_bed.run_all.sh`
Purpose: Batch-run `gff3_to_bed.py` over a directory of GFF3s and generate
combined `pave_hsa.bed` plus E6/E7 subsets.
Key parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for BEDs (also receives combined BEDs).

### `scripts/pave/gff3_to_csq_gff.py`
Purpose: Build a bcftools-csq-friendly GFF3 (gene/mRNA/CDS) from PaVE GFFs.
Used by `report_E6_E7_variant_effects.sh` to compute variant consequences.
Key parameters:
- `gff_dir`: directory of PaVE GFF/GFF3 files.
- `-o/--output`: output GFF3 path.
- `--fasta`: reference FASTA for seqid normalization.

### `scripts/pave/make_features_plot.py`
Purpose: Render a feature TSV as a gene map plot (visualization/QC).
Key parameters:
- `<tsv_file>`: features TSV (gene, start, end).
- `<output_file>`: plot output (png/pdf).
- `--verbose` / `--quiet`: logging control.

### `scripts/pave/make_features_plot.run_all.sh`
Purpose: Batch-generate feature plots for every TSV in a directory.
Key parameters:
- `<tsv_dir>`: directory of feature TSVs.
- `<out_dir>`: output directory for plots.

### `scripts/pave/make_tabix_dir.sh`
Purpose: Create bgzip+tabix indexes for a directory of GFF files.
Key parameters:
- `<gffdir>`: directory with GFF files.
- `<tabixdir>`: output directory for bgzip+tabix files.

## VirStrain aggregation

### `scripts/virstrain/aggregate_virstrain_results.py`
Purpose: Summarize VirStrain `VirStrain_report.txt` outputs across runs and
samples into a single TSV. Used by the VirStrain report pipeline.
Key parameters:
- `<results_dir>`: root containing `run/sample/VirStrain_report.txt`.
- `--maxstrains`: cap on number of strains listed before flagging.

### `scripts/virstrain/prepare_virstrain_multiqc_inputs.py`
Purpose: Reformat VirStrain strain tables into MultiQC-ready TSVs with sample IDs.
Key parameters:
- `--strains`: input strains TSV.
- `--out`: output MultiQC TSV.

## Phylogenetic tree preparation

### `scripts/phylo_tree/select_ncbi_genomes.sh`
Purpose: Select and rename NCBI Virus genomes for phylogenetic trees.
Optionally emits a full accession+country table for review.
Key parameters:
- `--init-selection`: create a starter selection TSV and exit.
- `<ncbi_tsv>` / `<ncbi_fasta>`: NCBI Virus metadata + FASTA.
- `<selected_tsv>` / `<selected_fasta>`: selection TSV and extracted FASTA.
- `<selected_renamed_fasta>`: FASTA with country/lineage prefixes.
Environment overrides:
- `ACC_COL`, `SELECTION_COLS`
- `RENAME_TSV`, `RENAME_ACC_COL`, `RENAME_PREFIX_COL`
- `ACC_COUNTRY_TSV`, `ACC_COUNTRY_COLS`
- `SKIP_ID`

### `scripts/phylo_tree/extract_lineages_fasta.sh`
Purpose: Extract lineage reference sequences from an NCBI FASTA.
Key parameters:
- `<lineages_tsv>`: lineage metadata TSV (accession column).
- `<ncbi_fasta>`: NCBI FASTA.
- `<output_fasta>`: extracted FASTA.
- `[accession_col]`: accession column in the TSV (default 6).

### `scripts/phylo_tree/rename_lineages.py`
Purpose: Rename FASTA headers using metadata TSV columns (e.g., prefix with
country or lineage). Used by the HPV16/18 selection scripts.
Key parameters:
- `<metadata_tsv>`: TSV with accession and prefix columns.
- `<accession>` / `<prefix>`: 1-based column indices for accession/prefix.
- `<input_fasta>` / `<output_fasta>`: input and renamed FASTA.

### `scripts/phylo_tree/fix_msa_formatting.py`
Purpose: Simplify FASTA headers in alignments to be compatible with
`virstrain_build` by truncating after the first `|` or `,`.
Key parameters:
- `<msa>`: input FASTA alignment.

### `scripts/phylo_tree/assign_lineages.py`
Purpose: Assign lineage labels to tree tips based on distance to reference tips
in a tree. Used to annotate tree outputs.
Key parameters:
- `treefile`: input Newick tree.
- `--refs-file`: TSV of lineage -> reference tip ID (or `LINEAGE_REFS` env).
- `--outgroups-file`: list of outgroup tips (or `OUTGROUPS_FILE` env).

### `scripts/phylo_tree/prepare_samples.sh`
Purpose: Build consensus sequences for samples (for tree inputs) using
BCF outputs from the mapping step and the PAVE reference FASTA.
Key parameters (environment overrides):
- `HPV_TYPE`: HPV type label (e.g., HPV16 or HPV18).
- `REF_NAME`, `REF_PATTERN`: reference ID/pattern to extract from PAVE.
- `OUT_DIR`: required output directory for consensus FASTAs (written under `OUT_DIR/samples_consensus/`).
- `PAVE_FASTA`: path to PAVE FASTA.
- `BCF_DIR` / `BCF_RUN_ID`: where to find per-sample BCFs.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: which samples to process.
- `STRAINS_TSV` / `STRAINS_MATCH`: strains table used to infer samples when `SAMPLES` is empty.

### `scripts/phylo_tree/extract_country_sequences.py`
Purpose: Extract sequences from a selected FASTA for a specific country, used
for target-country SNP comparisons.
Key parameters:
- `--selected-fasta`: FASTA with selected accessions.
- `--selected-metadata`: TSV with accession + country columns.
- `--country`: country name to filter.
- `--label-prefix`: optional prefix added to output IDs.
- `--output`: output FASTA path.

### `scripts/phylo_tree/build_tree_selection_tsv.py`
Purpose: Build a selected NCBI metadata TSV from an accession list and the NCBI TSV.
Key parameters:
- `--ncbi-tsv`: NCBI metadata TSV.
- `--selection-list`: accession list (one per line).
- `--columns`: comma-separated 1-based column indices to export.
- `--output`: output TSV path.

### `scripts/phylo_tree/render_tree_svg.py`
Purpose: Render an IQ-TREE Newick tree to offline SVG/PNG for MultiQC.
Key parameters:
- `--treefile`: Newick tree file.
- `--svg`: output SVG path.
- `--png`: optional output PNG path.
- `--layout`: `circular` (default) or `rectangular`.
- `--width` / `--height`: figure size controls.
- `--no-ladderize`: disable ladderization.
- `--use-branch-lengths`: render using branch lengths (default is topology-only depth to avoid skew from distant outgroups).

### `scripts/phylo_tree/compute_tree_stats.py`
Purpose: Summarize alignment and IQ-TREE statistics for MultiQC.
Key parameters:
- `--selected`, `--outgroups`, `--lineages`, `--samples`: input FASTAs.
- `--aligned`, `--trimmed`: alignment FASTAs.
- `--iqtree`: IQ-TREE report file.
- `--treefile`: Newick tree file.
- `--output`: TSV output path.

## Lineage SNP calling and comparisons

### `scripts/variants/lineage_snps_from_fasta.py`
Purpose: Call SNPs for lineage FASTA sequences relative to a reference, limited
to E6/E7 BED regions. Produces lineage-defining SNPs used for comparisons and
reports.
Key parameters:
- `--lineages`: FASTA of lineage sequences.
- `--ref`: reference FASTA (full PaVE).
- `--ref-name`: reference sequence name inside the FASTA.
- `--bed-dir`: directory with `pave_hsa.E6/E7.bed`.
- `--header`: include header row in output.

### `scripts/variants/compare_lineage_snps.py`
Purpose: Compare sample E6/E7 variants to lineage SNPs and report matching
lineages per variant.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/variants/compare_query_snps_to_lineages.py`
Purpose: Compare query SNPs (e.g., target-country subset) against lineage SNPs.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/variants/compare_query_snps_to_samples.py`
Purpose: Map query SNPs to sample IDs that share the same variants.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--variants`: sample variants TSV.
- `--output`: output TSV listing sample matches per query SNP.

### `scripts/variants/compare_samples_to_query_snps.py`
Purpose: For each sample variant, list which query SNP sets contain it.
Key parameters:
- `--variants`: sample variants TSV.
- `--query-snps`: query SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include (default HPV16/18).

### `scripts/variants/compare_sample_snp_sets_to_lineages.py`
Purpose: Compare each sample's SNP set to each lineage SNP set, computing
shared/unique counts and Jaccard similarity.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV with shared/unique counts.
- `--allow-strains`: strain prefixes to include.

### `scripts/variants/compare_sample_snp_sets_to_database.py`
Purpose: Compare each sample's SNP set to each database SNP set, computing
shared/unique counts and Jaccard similarity.
Key parameters:
- `--variants`: sample variants TSV.
- `--database-snps`: database SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include.

### `scripts/variants/summarize_hpv16_e6e7_variants_database.py`
Purpose: Summarize HPV16 E6/E7 variants across samples, database accessions,
lineages, and a reference, emitting compact per-ID variant lists.
Key parameters:
- `--sample-effects`: sample E6/E7 variant effects TSV.
- `--database-snps`: database SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--sample-list`: metadata TSV with sample IDs.
- `--database-fasta`: database HPV16 FASTA.
- `--lineage-fasta`: HPV16 lineage FASTA.
- `--ref-fasta`: reference FASTA.
- `--bed-dir`: directory with E6/E7 BED files.
- `--output`: output TSV path.
