# Scripts technical documentation

This document describes the purpose of each script in `scripts/` and the
pipeline context in which it is used. It also lists the most important CLI
parameters that affect pipeline behavior (or the environment variables/inputs
used when the script is run by Nextflow wrappers).

The scripts are grouped by the pipeline area they support. If a script is used
as a helper by another script/pipeline, that is stated explicitly.

## Centrifuge bucketing and taxonomy processing

### `aggregate_bucket_counts.py`
Purpose: Aggregates per-sample bucket assignment counts into run-level tables
used by the bucketing reports. It is the source of `absolute_counts.tsv` and
`relative_counts.tsv` used in MultiQC for the bucketing steps.
Key parameters:
- `bucket_ids_table`: taxonomy bucket ID → name mapping (drives column order).
- `root`: bucketing output root containing per-run `bucket_sizes/` tables.
- `outputdir`: where to write aggregate tables.
- `--skip`: bucket IDs to exclude from aggregation (e.g., human).
- `--no-abs` / `--no-rel`: disable one of the tables.

### `compute_lca.py`
Purpose: Computes the lowest common ancestor (LCA) for each read in the
Centrifuge TSV output. This collapses multiple taxonomic hits to a single
assignment per read, which is then used for bucket mapping.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp` used to traverse the tree.
- `<centrifuge_tsv>`: Centrifuge tabular output with read→taxid hits.
- `<outfile>`: LCA output TSV (read ID + LCA taxid).

### `assign_to_buckets.py`
Purpose: Assigns each taxonomic ID in a TSV to a bucket head (taxonomy node).
This is the core step for bucketing reads into curated taxonomic categories.
Key parameters:
- `<nodesdmp>`: NCBI taxonomy tree input.
- `<tsv_file>` / `<column>`: input TSV and taxid column (1-based).
- `<bucket_heads>...`: list of bucket head taxids.
- `<outfile>`: TSV with added bucket column.

### `bucketize_fastq.py`
Purpose: Splits FASTQ reads into per-bucket FASTQ files using the bucket
assignment TSV. Used to create bucket-specific readsets for downstream steps.
Key parameters:
- `<tsv_file>`: assignment table containing read IDs and bucket IDs.
- `<read_id_col>` / `<bucket_id_col>`: 1-based columns for read and bucket IDs.
- `<fastq_file>`: input FASTQ (gz or plain).
- `<bucket_basename>`: output prefix for `*.{bucket}.fastq.gz` files.
- `--skip`: bucket IDs to exclude from splitting.

### `build_centrifuge_db.sh`
Purpose: Downloads taxonomy + RefSeq sequences and builds a Centrifuge index.
Used for reproducible database creation (human + archaea/bacteria/viral by
default). This is a manual pre-processing script, not run by pipelines.
Key parameters:
- `--outdir`: output directory for taxonomy, library and index.
- `--taxonomy-date`: optional suffix for taxonomy folder.
- `--index-name`: index basename (used by Centrifuge `-x`).
- `--refseq-domains`: comma list of RefSeq domains to include.
- `--threads`: Centrifuge build thread count.

## Bowtie vs PAVE mapping and variant calling

### `identify_top_strains.py`
Purpose: Parses `samtools idxstats` output to identify top HPV strains per
sample. This drives downstream selection of strains and reporting tables.
Key parameters:
- `<idxstats_output.txt>`: input from `samtools idxstats`.
- `--threshold`: fraction of top strain count for “top” classification.
- `--mincount`: absolute count threshold for “top” classification.

### `aggregate_top_strains.sh`
Purpose: Aggregates `.top_strains` files across runs into a single table.
Used by the mapping-vs-PAVE MultiQC report.
Key parameters:
- `<output_root>`: root containing per-run `.top_strains` files.
- `<output_file>`: aggregated TSV output path.

### `covstats.py`
Purpose: Computes average depth and breadth of coverage per strain from
`samtools depth -aa` output. Optional feature-level coverage is included when
feature TSVs are provided.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: TSV output path.
- `<tsvfiles>`: directory of feature TSVs named `<strain>REF.tsv`.
- `--features`: comma list of features to compute (defaults to `E6,E7`).

### `depth_stats.py`
Purpose: Computes simple depth/breadth stats per strain (no feature breakdown).
This is used when feature-level outputs are not required.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: TSV output path.

### `aggregate_covstats.py`
Purpose: Aggregates `*.depth.stats` files into a single table per run/sample.
Used for downstream reporting and filtering based on depth/breadth thresholds.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats` files.
- `<output_file>`: aggregate TSV output.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `aggregate_depth_stats.py`
Purpose: Aggregates simple depth stats into a combined table, applying
thresholds for depth and breadth. Used in PAVE E6/E7 steps and reporting.
Key parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregate TSV output.
- `--depth`, `--breadth`: thresholds for including a strain.

### `covplot.py`
Purpose: Generates coverage plots that combine per-position depth with gene
feature annotations. Used to generate per-sample visual QC for mapped reads.
Key parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<strain_name>`: strain prefix to filter coverage lines.
- `<tsv_file>`: feature TSV (gene name, start, end).
- `<output_file>`: plot output path.

### `make_all_covplots.sh`
Purpose: Batch wrapper to generate coverage plots for all qualifying
run/sample/strain rows in a covstats table.
Key parameters:
- `<cov_stats.tsv>`: aggregated covstats table (run/sample/strain).
- `<depth_root>`: root containing `run/sample.depth` files.
- `<features_tsv_dir>`: feature TSV directory per strain.
- `[plots_outdir]`: optional output directory (defaults to `<depth_root>/plots`).

### `report_E6_E7_variants.sh`
Purpose: Extracts E6/E7 SNPs from per-sample BCFs using precomputed BED files.
Produces a raw TSV used by downstream comparison and reporting steps.
Key parameters:
- `<outputdir>`: run output root containing `.bcf.gz` files.
- `<bed_dir>`: directory with `pave_hsa.E6.bed` and `pave_hsa.E7.bed`.

### `report_E6_E7_variant_effects.sh`
Purpose: Computes functional consequences of E6/E7 variants using `bcftools csq`.
This depends on a csq-compatible GFF generated from PaVE and the reference FASTA.
Key parameters:
- `<outputdir>`: run output root with `.bcf.gz` files.
- `<bed_dir>`: directory with E6/E7 BEDs.
- `<gff3_dir>`: PaVE GFF directory (source for csq GFF conversion).
- `<ref_fasta>`: PAVE reference FASTA.

### `csq_to_tsv.py`
Purpose: Converts `bcftools csq` output into a flat TSV table (one row per
consequence) annotated with run/sample/gene metadata.
Key parameters:
- `--run`, `--sample`, `--gene`: identifiers used in output rows.
- `--tag`: INFO tag to parse (default `BCSQ`).
- `--no-header`: suppresses header row (for streaming multiple calls).

## PaVE reference feature derivation

### `gff3_to_features_tsv.py`
Purpose: Converts a PaVE GFF3 file to a simple TSV of feature start/end
positions (gene and regulatory regions). Used to drive coverage plots and
feature-specific coverage summaries.
Key parameters:
- `<gff3_file>`: input GFF3.
- `--verbose` / `--quiet`: logging control.

### `gff3_to_features_tsv.run_all.sh`
Purpose: Batch conversion of a directory of PaVE GFF3 files into feature TSVs.
Key parameters:
- `<gff_dir>`: directory of PaVE GFF files.
- `<out_dir>`: output directory for per-strain TSVs.

### `gff3_to_bed.py`
Purpose: Converts a PaVE GFF3 file into a BED file for gene/regulatory regions.
Used for E6/E7 variant extraction and lineage SNP calling.
Key parameters:
- `<gff3_file>`: input GFF3.
- `--verbose` / `--quiet`: logging control.

### `gff3_to_bed.run_all.sh`
Purpose: Batch conversion of a PaVE GFF directory to BED files, plus creation
of aggregate BEDs (`pave_hsa.bed`, `pave_hsa.E6.bed`, `pave_hsa.E7.bed`).
Key parameters:
- `<gff_dir>`: directory of PaVE GFF files.
- `<out_dir>`: output directory for BEDs.

### `gff3_to_csq_gff.py`
Purpose: Generates a bcftools-csq-friendly GFF3 by normalizing PaVE GFF
features to gene/mRNA/CDS relationships and removing FASTA sections. This is
required by `report_E6_E7_variant_effects.sh`.
Key parameters:
- `gff_dir`: directory containing PaVE GFF/GFF3 files.
- `-o/--output`: output GFF3 path.
- `--fasta`: reference FASTA to normalize sequence IDs.

### `make_features_plot.py`
Purpose: Generates per-strain feature schematic plots from feature TSVs.
These are auxiliary plots for reference data QC and reporting.
Key parameters:
- `<tsv_file>`: feature TSV (feature, start, end).
- `<output_file>`: plot output path.

### `make_features_plot.run_all.sh`
Purpose: Batch wrapper to generate feature plots for all TSVs in a directory.
Key parameters:
- `<tsv_dir>`: directory of feature TSVs.
- `<out_dir>`: output directory for plots.

### `make_tabix_dir.sh`
Purpose: Creates a tabix-indexed directory of PaVE GFF files (bgzip + tabix).
This is used for tools that require random access to GFF features.
Key parameters:
- `<gffdir>`: directory of `.gff` files.
- `<tabixdir>`: output directory for `.gff.gz` + `.tbi`.

## VirStrain aggregation

### `aggregate_results.py`
Purpose: Aggregates VirStrain outputs into a summary table of top strains per
run and sample. Used in the preliminary analysis VirStrain step reports.
Key parameters:
- `<results_dir>`: root of VirStrain outputs (`run/sample/VirStrain_report.txt`).
- `--maxstrains`: maximum number of strains to report before marking as too many.

## HPV16/HPV18 reference preparation for phylogenetic trees

### `hpv16_select_ncbi_genomes.sh`
Purpose: Creates and applies a selection list for HPV16 NCBI Virus genomes and
renames headers with country/lineage prefixes. This supports curated tree inputs.
Key parameters:
- `--init-selection`: create the initial selection TSV and exit.
- `<ncbi_tsv>`, `<ncbi_fasta>`: NCBI Virus metadata and FASTA inputs.
- `<selected_tsv>`, `<selected_fasta>`, `<selected_renamed_fasta>`: outputs.
- Environment overrides: `NCBI_ACC_COL`, `NCBI_COUNTRY_COL`, `SELECTED_ACC_COL`,
  `SELECTED_PREFIX_COL`, `SKIP_ID`.

### `hpv18_select_ncbi_genomes.sh`
Purpose: Same as `hpv16_select_ncbi_genomes.sh`, but for HPV18 inputs.
Key parameters: identical to HPV16 selection (inputs/outputs are HPV18-specific).

### `hpv16_extract_lineages_fasta.sh`
Purpose: Extracts lineage reference sequences from NCBI Virus FASTA using a
lineage TSV list. Used to build the lineage reference FASTA for HPV16.
Key parameters:
- `<lineages_tsv>`: lineage metadata (accessions).
- `<ncbi_fasta>`: NCBI Virus FASTA input.
- `<output_fasta>`: extracted lineage FASTA.
- `[accession_col]`: optional accession column (default 6).

### `hpv18_extract_lineages_fasta.sh`
Purpose: HPV18 equivalent of lineage FASTA extraction.
Key parameters: same as HPV16 extraction.

### `rename_lineages.py`
Purpose: Renames FASTA headers using metadata TSV columns (e.g., country or
lineage). Used after NCBI selection to embed informative prefixes.
Key parameters:
- `<metadata_tsv>`: metadata TSV.
- `<accession>`: accession column index (1-based).
- `<prefix>`: prefix column index (1-based).
- `<input_fasta>`, `<output_fasta>`: FASTA input/output.

### `extract_country_sequences.py`
Purpose: Extracts sequences for a specific country from curated FASTA + TSV,
used for Cambodia-specific analyses in the targeted workflow.
Key parameters:
- `--selected-fasta`, `--selected-metadata`: curated FASTA + TSV.
- `--country`: country name to filter.
- `--label-prefix`: prefix for output sequence IDs.
- `--output`: output FASTA.

### `fix_msa_formatting.py`
Purpose: Sanitizes FASTA headers in MSA files to ensure compatibility with
VirStrain build steps (removes everything after `|` or `,`).
Key parameters:
- `<msa>`: input MSA FASTA.

### `hpv16_prepare_samples.sh`
Purpose: Builds HPV16 consensus sequences from sample BCFs and combines them
into a `samples.fasta` used for phylogenetic tree steps.
Key parameters (environment overrides):
- `PAVE_FASTA`: source reference FASTA.
- `HPV16REF_FASTA`: output reference FASTA path.
- `BCF_DIR` / `BCF_RUN_ID`: mapping-vs-PAVE output to use.
- `OUT_DIR`: output directory (required).
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: sample selection.

### `hpv18_prepare_samples.sh`
Purpose: Builds HPV18 consensus sequences from sample BCFs and combines them
into a `samples.fasta`. It can infer HPV18 samples from `strains.tsv`.
Key parameters (environment overrides):
- `PAVE_FASTA`, `HPV18REF_FASTA`, `BCF_DIR`, `BCF_RUN_ID`, `OUT_DIR`.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`.
- `STRAINS_TSV`: used to auto-select HPV18 samples.

### `assign_hpv18_lineages.py`
Purpose: Assigns HPV18 lineages to tree tips by nearest reference distance in
an inferred tree. Used in downstream HPV18 tree reporting.
Key parameters:
- `treefile`: Newick tree input.
- `--refs-file`: lineage reference tip mapping TSV.
- `--outgroups-file`: outgroup tip list.

## Lineage SNP calling and comparisons

### `lineage_snps_from_fasta.py`
Purpose: Calls E6/E7 SNPs for lineage reference FASTA sequences by aligning to
reference and extracting variants within E6/E7 BEDs.
Key parameters:
- `--lineages`: lineage FASTA.
- `--ref`: reference FASTA (PAVE).
- `--ref-name`: exact reference sequence ID.
- `--bed-dir`: directory containing `pave_hsa.E6.bed` / `pave_hsa.E7.bed`.
- `--header`: print header row.

### `compare_lineage_snps.py`
Purpose: Annotates sample E6/E7 variants with lineage memberships by matching
variant coordinates against lineage SNPs.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV.

### `compare_query_snps_to_lineages.py`
Purpose: Annotates query SNPs (e.g., Cambodia) with lineages sharing those SNPs.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV.

### `compare_query_snps_to_samples.py`
Purpose: Annotates query SNPs with samples sharing those SNPs.
Key parameters:
- `--query-snps`: query SNPs TSV.
- `--variants`: sample variants TSV.
- `--output`: output TSV.

### `compare_samples_to_query_snps.py`
Purpose: Annotates each sample variant with matching query SNPs (e.g., Cambodia)
and counts overlaps. Used for sample-vs-query reporting.
Key parameters:
- `--variants`: sample variants TSV.
- `--query-snps`: query SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: comma list of strain prefixes to include.

### `compare_sample_snp_sets_to_cambodia.py`
Purpose: Compares SNP sets between each sample and each Cambodia accession,
computing shared/unique SNPs and Jaccard overlap.
Key parameters:
- `--variants`: sample variants TSV.
- `--cambodia-snps`: Cambodia SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefix filter (defaults HPV16/HPV18).

### `compare_sample_snp_sets_to_lineages.py`
Purpose: Compares SNP sets between each sample and each lineage, computing
shared/unique SNPs and Jaccard overlap.
Key parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefix filter (defaults HPV16/HPV18).

### `summarize_hpv16_e6e7_variants.py`
Purpose: Produces a compact per-entity summary of HPV16 E6/E7 variants for
samples, Cambodia accessions, and lineages. This table is used in the
`snps_samples_vs_db` MultiQC report.
Key parameters:
- `--sample-effects`: E6/E7 variant effects TSV.
- `--cambodia-snps`: Cambodia SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--sample-list`: samples metadata TSV.
- `--cambodia-fasta`, `--lineage-fasta`, `--ref-fasta`: FASTA inputs.
- `--bed-dir`: directory with E6/E7 BEDs.
- `--output`: output TSV path.

## Miscellaneous pipeline helpers

### `make_features_plot.run_all.sh`
Purpose: Batch wrapper for generating per-strain feature plots for all TSVs.
Key parameters:
- `<tsv_dir>`: directory of feature TSVs.
- `<out_dir>`: output directory for plots.

