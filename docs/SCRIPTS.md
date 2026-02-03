# Scripts documentation

This document describes each script in `scripts/`, its purpose, where it is
used in the pipeline (if applicable), and the key parameters or environment
inputs that affect behavior. Scripts are grouped in concern-based
subdirectories that mirror the section headers below.

## Centrifuge bucketing and taxonomy processing

### `scripts/centrifuge_bucketing/build_centrifuge_db.sh`
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

### `scripts/centrifuge_bucketing/compute_lca.py`
Purpose: Compute the lowest common ancestor (LCA) for each read in Centrifuge
TSV output. This collapses multiple taxonomic hits to a single assignment that
is used by the bucketing pipeline.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp` file.
- `<centrifuge_tsv>`: Centrifuge tabular output file.
- `<outfile>`: output TSV with read IDs and LCA tax IDs.

### `scripts/centrifuge_bucketing/assign_to_buckets.py`
Purpose: Assign each taxonomic ID in a TSV to a bucket head (taxonomy node).
This is the core step for bucketing reads into curated taxonomic categories.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp`.
- `<tsv_file>` / `<column>`: input TSV and 1-based taxid column.
- `<bucket_heads>...`: list of bucket head taxids.
- `<outfile>`: output TSV with appended bucket column.

### `scripts/centrifuge_bucketing/bucketize_fastq.py`
Purpose: Split FASTQ reads into per-bucket FASTQ files using the bucket
assignment TSV. Used to create bucket-specific readsets for downstream steps.
Key parameters:
- `<tsv_file>`: assignment table containing read IDs and bucket IDs.
- `<read_id_col>` / `<bucket_id_col>`: 1-based columns for read and bucket IDs.
- `<fastq_file>`: input FASTQ (plain or gzip).
- `<bucket_basename>`: output prefix for `*.{bucket}.fastq.gz` files.
- `--skip`: bucket IDs to exclude from splitting.

### `scripts/centrifuge_bucketing/aggregate_bucket_counts.py`
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

## Bowtie vs PaVE mapping, coverage, and variant calling

### `scripts/bowtie_vs_pave/identify_top_strains.py`
Purpose: Parse `samtools idxstats` output to identify top HPV strains per
sample based on relative abundance and minimum read count. Used in the mapping
pipeline and reporting.
Key parameters:
- `<idxstats_output.txt>`: input from `samtools idxstats`.
- `--threshold`: ratio to top strain required to be considered "top".
- `--mincount`: minimum reads required to be considered.

### `scripts/bowtie_vs_pave/aggregate_top_strains.sh`
Purpose: Aggregate per-sample `.top_strains` files across runs into a single
TSV used by mapping-vs-PaVE reports and MultiQC.
Key parameters:
- `<output_root>`: root containing per-run `.top_strains` files.
- `<output_file>`: aggregated TSV output path.

### `scripts/bowtie_vs_pave/covstats.py`
Purpose: Compute per-strain coverage depth and breadth from `samtools depth -aa`.
Optionally computes coverage over features (E6/E7) using feature TSVs.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with depth stats.
- `<tsvfiles>`: optional directory of feature TSVs (`<strain>REF.tsv`).
- `--features`: comma-separated feature names (default `E6,E7`).

### `scripts/bowtie_vs_pave/depth_stats.py`
Purpose: Compute mean depth and breadth per strain from a depth file. Used
when a simpler depth summary is sufficient.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with mean depth and breadth.

### `scripts/bowtie_vs_pave/aggregate_covstats.py`
Purpose: Aggregate per-sample `*.depth.stats` files into a combined table
filtered by minimum depth/breadth thresholds for reporting and MultiQC.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/bowtie_vs_pave/aggregate_depth_stats.py`
Purpose: Aggregate simple depth statistics across runs, filtering by mean depth
and breadth thresholds.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/bowtie_vs_pave/covplot.py`
Purpose: Produce coverage plots with gene features annotated from TSV files.
Used for manual QC/visualization of coverage profiles.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<strain_name>`: strain to select from depth file.
- `<tsv_file>`: feature TSV (gene name, start, end).
- `<output_file>`: plot output (png/pdf).

### `scripts/bowtie_vs_pave/make_all_covplots.sh`
Purpose: Batch-generate coverage plots for all samples listed in a covstats
summary file.
Key parameters:
- `<cov_stats.tsv>`: aggregated coverage stats (run/sample/strain list).
- `<depth_root>`: root containing per-run depth files.
- `<features_tsv_dir>`: directory of feature TSVs.
- `[plots_outdir]`: optional output directory.

### `scripts/bowtie_vs_pave/report_E6_E7_variants.sh`
Purpose: Extract E6/E7 variants from per-sample BCFs using BED intervals. Used
by the bowtie-vs-PaVE pipeline to build variants tables.
Key parameters:
- `<outputdir>`: root containing `run_id/*.bcf.gz` files.
- `<bed_dir>`: directory with `pave_hsa.E6.bed` and `pave_hsa.E7.bed`.

### `scripts/bowtie_vs_pave/report_E6_E7_variant_effects.sh`
Purpose: Use bcftools csq to annotate E6/E7 variants and emit a TSV with
consequences via `csq_to_tsv.py`.
Key parameters:
- `<outputdir>`: root containing per-run BCFs.
- `<bed_dir>`: directory with E6/E7 BED files.
- `<gff3_dir>`: directory of PaVE GFF3s.
- `<ref_fasta>`: reference FASTA used for csq annotations.

### `scripts/bowtie_vs_pave/csq_to_tsv.py`
Purpose: Convert bcftools csq output (read from stdin) to TSV rows with
run/sample/gene fields, one row per consequence.
Key parameters:
- `--run`: run ID label to include in the TSV.
- `--sample`: sample ID label to include.
- `--gene`: gene label (E6/E7).
- `--tag`: INFO tag containing csq annotations (default `BCSQ`).
- `--no-header`: suppress header emission (used for multi-file concatenation).

## PaVE reference feature derivation

### `scripts/pave_reference/gff3_to_features_tsv.py`
Purpose: Convert a single PaVE GFF3 file into a TSV of gene/regulatory
features for coverage stats and plotting.
Key parameters:
- `<gff3_file>`: PaVE GFF3 file.
- `--verbose` / `--quiet`: logging control.

### `scripts/pave_reference/gff3_to_features_tsv.run_all.sh`
Purpose: Batch-run `gff3_to_features_tsv.py` over a directory of GFF3s.
Key parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for TSVs.

### `scripts/pave_reference/gff3_to_bed.py`
Purpose: Convert a PaVE GFF3 into a BED file (gene/regulatory regions). These
BEDs are used to filter E6/E7 variants and lineage SNP calling.
Key parameters:
- `<gff3_file>`: PaVE GFF3 file.
- `--verbose` / `--quiet`: logging control.

### `scripts/pave_reference/gff3_to_bed.run_all.sh`
Purpose: Batch-run `gff3_to_bed.py` over a directory of GFF3s and generate
combined `pave_hsa.bed` plus E6/E7 subsets.
Key parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for BEDs (also receives combined BEDs).

### `scripts/pave_reference/gff3_to_csq_gff.py`
Purpose: Build a bcftools-csq-friendly GFF3 (gene/mRNA/CDS) from PaVE GFFs.
Used by `report_E6_E7_variant_effects.sh` to compute variant consequences.
Key parameters:
- `gff_dir`: directory of PaVE GFF/GFF3 files.
- `-o/--output`: output GFF3 path.
- `--fasta`: reference FASTA for seqid normalization.

### `scripts/pave_reference/make_features_plot.py`
Purpose: Render a feature TSV as a gene map plot (visualization/QC).
Key parameters:
- `<tsv_file>`: features TSV (gene, start, end).
- `<output_file>`: plot output (png/pdf).
- `--verbose` / `--quiet`: logging control.

### `scripts/pave_reference/make_features_plot.run_all.sh`
Purpose: Batch-generate feature plots for every TSV in a directory.
Key parameters:
- `<tsv_dir>`: directory of feature TSVs.
- `<out_dir>`: output directory for plots.

### `scripts/pave_reference/make_tabix_dir.sh`
Purpose: Create bgzip+tabix indexes for a directory of GFF files.
Key parameters:
- `<gffdir>`: directory with GFF files.
- `<tabixdir>`: output directory for bgzip+tabix files.

## VirStrain aggregation

### `scripts/virstrain/aggregate_results.py`
Purpose: Summarize VirStrain `VirStrain_report.txt` outputs across runs and
samples into a single TSV. Used by the VirStrain report pipeline.
Key parameters:
- `<results_dir>`: root containing `run/sample/VirStrain_report.txt`.
- `--maxstrains`: cap on number of strains listed before flagging.

## Phylogenetic tree preparation

### `scripts/phylo_tree/hpv16_select_ncbi_genomes.sh`
Purpose: Select and rename HPV16 NCBI Virus genomes for phylogenetic trees.
Creates/uses a user-edited TSV of selected accessions.
Key parameters:
- `--init-selection`: create a starter selection TSV and exit.
- `<ncbi_tsv>` / `<ncbi_fasta>`: NCBI Virus metadata + FASTA.
- `<selected_tsv>` / `<selected_fasta>`: selection TSV and extracted FASTA.
- `<selected_renamed_fasta>`: FASTA with country/lineage prefixes.
Environment overrides:
- `NCBI_ACC_COL`, `NCBI_COUNTRY_COL`, `SELECTED_ACC_COL`, `SELECTED_PREFIX_COL`, `SKIP_ID`.

### `scripts/phylo_tree/hpv18_select_ncbi_genomes.sh`
Purpose: Select and rename HPV18 NCBI Virus genomes using a two-step selection
workflow (acc+country table, then selected subset).
Key parameters:
- `--init-selection`: create the selection TSV and exit.
- `<ncbi_tsv>` / `<ncbi_fasta>`: NCBI Virus metadata + FASTA.
- `<acc_country_tsv>`: full accession/country table.
- `<acc_country_selected_tsv>`: edited selection table.
- `<selected_fasta>` / `<selected_renamed_fasta>`: output FASTAs.
Environment overrides:
- `ACCESSION_COL`, `COUNTRY_COL`, `SKIP_ID`.

### `scripts/phylo_tree/hpv16_extract_lineages_fasta.sh`
Purpose: Extract lineage reference sequences from the HPV16 NCBI FASTA.
Key parameters:
- `<lineages_tsv>`: lineage metadata TSV (accession column).
- `<ncbi_fasta>`: HPV16 NCBI FASTA.
- `<output_fasta>`: extracted FASTA.
- `[accession_col]`: accession column in the TSV (default 6).

### `scripts/phylo_tree/hpv18_extract_lineages_fasta.sh`
Purpose: Extract lineage reference sequences from the HPV18 NCBI FASTA.
Key parameters:
- `<lineages_tsv>`: lineage metadata TSV (accession column).
- `<ncbi_fasta>`: HPV18 NCBI FASTA.
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

### `scripts/phylo_tree/assign_hpv18_lineages.py`
Purpose: Assign HPV18 lineage labels to tree tips based on distance to
reference tips in a tree. Used to annotate tree outputs.
Key parameters:
- `treefile`: input Newick tree.
- `--refs-file`: TSV of lineage -> reference tip ID (default from metadata).
- `--outgroups-file`: list of outgroup tips (default from metadata).

### `scripts/phylo_tree/hpv16_prepare_samples.sh`
Purpose: Build HPV16 consensus sequences for samples (for tree inputs) using
BCF outputs from the mapping step and the PAVE reference FASTA.
Key parameters (environment overrides):
- `OUT_DIR`: required output directory for consensus FASTAs.
- `PAVE_FASTA`: path to PAVE FASTA.
- `BCF_DIR` / `BCF_RUN_ID`: where to find per-sample BCFs.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: which samples to process.

### `scripts/phylo_tree/hpv18_prepare_samples.sh`
Purpose: Build HPV18 consensus sequences for samples (for tree inputs) using
BCF outputs and the PAVE reference FASTA, plus strains.tsv for sample detection.
Key parameters (environment overrides):
- `OUT_DIR`: required output directory for consensus FASTAs.
- `PAVE_FASTA`, `HPV18REF_FASTA`: reference FASTA locations.
- `BCF_DIR` / `BCF_RUN_ID`: where to find per-sample BCFs.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: which samples to process.
- `STRAINS_TSV`: strains table used to infer HPV18 samples when `SAMPLES` is empty.

### `scripts/phylo_tree/extract_country_sequences.py`
Purpose: Extract sequences from a selected FASTA for a specific country, used
for target-country SNP comparisons.
Key parameters:
- `--selected-fasta`: FASTA with selected accessions.
- `--selected-metadata`: TSV with accession + country columns.
- `--country`: country name to filter.
- `--label-prefix`: optional prefix added to output IDs.
- `--output`: output FASTA path.

## Lineage SNP calling and comparisons

### `scripts/lineage_snps/lineage_snps_from_fasta.py`
Purpose: Call SNPs for lineage FASTA sequences relative to a reference, limited
to E6/E7 BED regions. Produces lineage-defining SNPs used for comparisons and
reports.
Key parameters:
- `--lineages`: FASTA of lineage sequences.
- `--ref`: reference FASTA (full PaVE).
- `--ref-name`: reference sequence name inside the FASTA.
- `--bed-dir`: directory with `pave_hsa.E6/E7.bed`.
- `--header`: include header row in output.

### `scripts/lineage_snps/compare_lineage_snps.py`
Purpose: Compare sample E6/E7 variants to lineage SNPs and report matching
lineages per variant.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/lineage_snps/compare_query_snps_to_lineages.py`
Purpose: Compare query SNPs (e.g., target-country subset) against lineage SNPs.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/lineage_snps/compare_query_snps_to_samples.py`
Purpose: Map query SNPs to sample IDs that share the same variants.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--variants`: sample variants TSV.
- `--output`: output TSV listing sample matches per query SNP.

### `scripts/lineage_snps/compare_samples_to_query_snps.py`
Purpose: For each sample variant, list which query SNP sets contain it.
Key parameters:
- `--variants`: sample variants TSV.
- `--query-snps`: query SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include (default HPV16/18).

### `scripts/lineage_snps/compare_sample_snp_sets_to_lineages.py`
Purpose: Compare each sample's SNP set to each lineage SNP set, computing
shared/unique counts and Jaccard similarity.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV with shared/unique counts.
- `--allow-strains`: strain prefixes to include.

### `scripts/lineage_snps/compare_sample_snp_sets_to_database.py`
Purpose: Compare each sample's SNP set to each database SNP set, computing
shared/unique counts and Jaccard similarity.
Key parameters:
- `--variants`: sample variants TSV.
- `--database-snps`: database SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include.

### `scripts/lineage_snps/summarize_hpv16_e6e7_variants_database.py`
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
