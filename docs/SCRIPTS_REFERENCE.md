# Scripts reference (technical)

This document explains the purpose of each script under `scripts/` and the
key CLI parameters that matter for the pipelines and manual preparation steps.
Where relevant, the notes call out which pipeline step consumes the script's
outputs.

## Centrifuge bucketing support

### `scripts/build_centrifuge_db.sh`
Purpose: Build a Centrifuge index (human + RefSeq domains) plus taxonomy data
used by the bucketing pipeline. This is a preparation step that produces the
`params.index` and `params.taxdump` inputs consumed by the bucketing workflows.
Key CLI parameters:
- `--outdir`: output root that will hold taxonomy, library, and index files.
- `--taxonomy-date`: optional date suffix for taxonomy dir naming.
- `--index-name`: index base name (final index path is `<outdir>/<index-name>`).
- `--threads`: number of build threads (defaults to `$THREADS` or 24).
- `--refseq-domains`: comma-separated RefSeq domains to download.

### `scripts/compute_lca.py`
Purpose: Given Centrifuge's tabular output, computes the lowest common ancestor
(LCA) for each read using `nodes.dmp`. This LCA assignment is used by the
bucketing pipeline to collapse multiple hits to a single taxonomy ID.
Key CLI parameters:
- `<nodesdmp>`: path to NCBI taxonomy `nodes.dmp` file.
- `<centrifuge_tsv>`: Centrifuge tabular output file.
- `<outfile>`: output TSV with read IDs and LCA tax IDs.

### `scripts/assign_to_buckets.py`
Purpose: Map Centrifuge taxonomy IDs to configured bucket heads. Used to place
reads into HPV buckets or root when no bucket head is an ancestor.
Key CLI parameters:
- `<nodesdmp>`: NCBI taxonomy `nodes.dmp`.
- `<tsv_file>`: input TSV with taxonomy IDs.
- `<column>`: 1-based column index containing taxonomy IDs.
- `<outfile>`: output TSV with appended `bucket` column.
- `<bucket_heads>...`: list of bucket head taxonomy IDs.

### `scripts/bucketize_fastq.py`
Purpose: Split a FASTQ file into per-bucket FASTQs using the read-to-bucket TSV
produced by the LCA + bucket assignment steps.
Key CLI parameters:
- `<tsv_file>`: TSV mapping read IDs to bucket IDs.
- `<read_id_col>` / `<bucket_id_col>`: 1-based columns for read and bucket IDs.
- `<fastq_file>`: input FASTQ (plain or gzip).
- `<bucket_basename>`: output prefix for bucket FASTQs.
- `--skip`: comma-separated bucket IDs to ignore (e.g., controls).

### `scripts/aggregate_bucket_counts.py`
Purpose: Aggregate bucket size files across runs/samples into summary tables.
Used by bucketing reports to compare absolute and relative counts by bucket.
Key CLI parameters:
- `<bucket_ids_table>`: TSV mapping bucket IDs to bucket names.
- `<root>`: root containing `run_id/bucket_sizes/*.tsv`.
- `<outputdir>`: directory for output summary tables.
- `--abs-fname` / `--rel-fname`: output filenames.
- `--skip`: comma-separated bucket IDs to omit.
- `--no-abs` / `--no-rel`: disable absolute/relative outputs.

## Mapping + coverage statistics

### `scripts/identify_top_strains.py`
Purpose: Parse `samtools idxstats` output and label top strains based on
relative abundance and minimum read count. Used by bowtie-vs-PAVE mapping.
Key CLI parameters:
- `<idxstats_output.txt>`: idxstats input file.
- `--threshold`: ratio to top strain required to be considered "top".
- `--mincount`: minimum reads required to be considered.

### `scripts/covstats.py`
Purpose: Compute per-strain coverage depth and breadth from `samtools depth -aa`.
Optionally computes coverage over features (E6/E7) using feature TSVs.
Key CLI parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with depth stats.
- `<tsvfiles>`: optional directory of feature TSVs (`<strain>REF.tsv`).
- `--features`: comma-separated feature names (default `E6,E7`).

### `scripts/depth_stats.py`
Purpose: Compute mean depth and breadth for each strain from a depth file.
Used when a simpler depth summary is needed.
Key CLI parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<output_file>`: output TSV with mean depth and breadth.

### `scripts/aggregate_covstats.py`
Purpose: Aggregate per-sample `*.depth.stats` into a combined table filtered by
minimum depth/breadth thresholds. Drives summary reports and MultiQC tables.
Key CLI parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/aggregate_depth_stats.py`
Purpose: Aggregate simple depth statistics files across runs, filtering by
mean depth and breadth thresholds.
Key CLI parameters:
- `<input_dir>`: root containing `run_id/*.depth.stats`.
- `<output_file>`: aggregated output TSV.
- `--depth`: minimum mean depth threshold.
- `--breadth`: minimum breadth threshold.

### `scripts/covplot.py`
Purpose: Produce coverage plots with gene features annotated from TSV files.
Used for manual QC/visualization of coverage profiles.
Key CLI parameters:
- `<depth_file>`: `samtools depth -aa` output.
- `<strain_name>`: strain to select from depth file.
- `<tsv_file>`: feature TSV (gene name, start, end).
- `<output_file>`: plot output (png/pdf).
- `--verbose` / `--quiet`: logging control.

### `scripts/make_all_covplots.sh`
Purpose: Batch-generate coverage plots for all samples listed in a cov_stats
summary file. Used for QC plotting across runs.
Key CLI parameters:
- `<cov_stats.tsv>`: aggregated coverage stats (run/sample/strain list).
- `<depth_root>`: root containing per-run depth files.
- `<features_tsv_dir>`: directory of feature TSVs.
- `[plots_outdir]`: optional output directory.

### `scripts/aggregate_top_strains.sh`
Purpose: Combine per-sample `*.top_strains` files into a single TSV. Used by
bowtie-vs-PAVE reports and MultiQC tables.
Key CLI parameters:
- `<output_root>`: directory containing `run_id/*.top_strains`.
- `<output_file>`: merged TSV file.

### `scripts/aggregate_results.py`
Purpose: Summarize VirStrain `VirStrain_report.txt` outputs across runs and
samples into a single TSV. Used by the VirStrain report pipeline.
Key CLI parameters:
- `<results_dir>`: root containing `run/sample/VirStrain_report.txt`.
- `--maxstrains`: cap on number of strains listed before flagging.

## PAVE reference processing

### `scripts/gff3_to_features_tsv.py`
Purpose: Convert a single PaVE GFF3 file into a TSV of gene/regulatory features
for coverage stats and plotting.
Key CLI parameters:
- `<gff3_file>`: PaVE GFF3 file for one HPV reference.
- `--verbose` / `--quiet`: logging control.

### `scripts/gff3_to_features_tsv.run_all.sh`
Purpose: Batch-run `gff3_to_features_tsv.py` over a directory of GFF3s.
Used to build the features TSV directory consumed by mapping pipelines.
Key CLI parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for TSVs.

### `scripts/gff3_to_bed.py`
Purpose: Convert a single PaVE GFF3 into a BED file (gene/regulatory regions).
These BEDs are used to filter E6/E7 variants.
Key CLI parameters:
- `<gff3_file>`: PaVE GFF3 file.
- `--verbose` / `--quiet`: logging control.

### `scripts/gff3_to_bed.run_all.sh`
Purpose: Batch-run `gff3_to_bed.py` over a directory of GFF3s and generate
combined `pave_hsa.bed` plus E6/E7 subsets.
Key CLI parameters:
- `<gff_dir>`: directory of PaVE GFF3 files.
- `<out_dir>`: output directory for BEDs (also receives combined BEDs).

### `scripts/gff3_to_csq_gff.py`
Purpose: Build a bcftools-csq-friendly GFF3 (gene/mRNA/CDS) from PaVE GFFs.
Used by `report_E6_E7_variant_effects.sh` to compute variant consequences.
Key CLI parameters:
- `gff_dir`: directory of PaVE GFF/GFF3 files.
- `-o/--output`: output GFF3 path.
- `--fasta`: reference FASTA for seqid normalization.

### `scripts/make_features_plot.py`
Purpose: Render a feature TSV as a gene map plot (used for visualization/QC).
Key CLI parameters:
- `<tsv_file>`: features TSV (gene, start, end).
- `<output_file>`: plot output (png/pdf).
- `--verbose` / `--quiet`: logging control.

### `scripts/make_features_plot.run_all.sh`
Purpose: Batch-generate feature plots for every TSV in a directory.
Key CLI parameters:
- `<tsv_dir>`: directory of feature TSVs.
- `<out_dir>`: output directory for plots.

### `scripts/make_tabix_dir.sh`
Purpose: Create bgzip+tabix indexes for a directory of GFF files. Used when
indexing GFFs for downstream tools that expect tabix-indexed annotations.
Key CLI parameters:
- `<gffdir>`: directory with GFF files.
- `<tabixdir>`: output directory for bgzip+tabix files.

## Variant extraction and effects

### `scripts/report_E6_E7_variants.sh`
Purpose: Extract E6/E7 variants from per-sample BCFs using BED intervals.
Used by the bowtie-vs-PAVE mapping pipeline to build variants tables.
Key CLI parameters:
- `<outputdir>`: root containing `run_id/*.bcf.gz` files.
- `<bed_dir>`: directory with `pave_hsa.E6.bed` and `pave_hsa.E7.bed`.

### `scripts/report_E6_E7_variant_effects.sh`
Purpose: Use bcftools csq to annotate E6/E7 variants and emit a TSV with
consequences via `csq_to_tsv.py`.
Key CLI parameters:
- `<outputdir>`: root containing per-run BCFs.
- `<bed_dir>`: directory with E6/E7 BED files.
- `<gff3_dir>`: directory of PaVE GFF3s.
- `<ref_fasta>`: reference FASTA used for csq annotations.

### `scripts/csq_to_tsv.py`
Purpose: Convert bcftools csq VCF output (read from stdin) to TSV rows with
run/sample/gene fields, one row per consequence.
Key CLI parameters:
- `--run`: run ID label to include in the TSV.
- `--sample`: sample ID label to include.
- `--gene`: gene label (E6/E7).
- `--tag`: INFO tag containing csq annotations (default `BCSQ`).
- `--no-header`: suppress header emission (used for multi-file concatenation).

## Lineage SNPs and comparisons

### `scripts/lineage_snps_from_fasta.py`
Purpose: Call SNPs for lineage FASTA sequences relative to a reference, limited
to E6/E7 BED regions. Produces a TSV of lineage-defining SNPs used for
comparisons and reports.
Key CLI parameters:
- `--lineages`: FASTA of lineage sequences.
- `--ref`: reference FASTA (full PAVE).
- `--ref-name`: reference sequence name inside the FASTA.
- `--bed-dir`: directory with `pave_hsa.E6/E7.bed`.
- `--header`: include header row in output.

### `scripts/compare_lineage_snps.py`
Purpose: Compare sample E6/E7 variants to lineage SNPs and report matching
lineages per variant.
Key CLI parameters:
- `--variants`: sample variants TSV (from `report_E6_E7_variants.sh`).
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/compare_query_snps_to_lineages.py`
Purpose: Compare query SNPs (e.g., Cambodia subset) against lineage SNPs.
Used by the targeted-analysis SNP comparison reports.
Key CLI parameters:
- `--query-snps`: query SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output comparison TSV.

### `scripts/compare_query_snps_to_samples.py`
Purpose: Map query SNPs to sample IDs that share the same variants.
Key CLI parameters:
- `--query-snps`: query SNPs TSV.
- `--variants`: sample variants TSV.
- `--output`: output TSV listing sample matches per query SNP.

### `scripts/compare_samples_to_query_snps.py`
Purpose: For each sample variant, list which query SNP sets contain it.
Used for sample-to-Cambodia comparisons.
Key CLI parameters:
- `--variants`: sample variants TSV.
- `--query-snps`: query SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include (default HPV16/18).

### `scripts/compare_sample_snp_sets_to_lineages.py`
Purpose: Compare each sample's SNP set to each lineage SNP set, computing
shared/unique counts and Jaccard similarity.
Key CLI parameters:
- `--variants`: sample variants TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--output`: output TSV with shared/unique counts.
- `--allow-strains`: strain prefixes to include.

### `scripts/compare_sample_snp_sets_to_cambodia.py`
Purpose: Compare each sample's SNP set to each Cambodia SNP set, computing
shared/unique counts and Jaccard similarity.
Key CLI parameters:
- `--variants`: sample variants TSV.
- `--cambodia-snps`: Cambodia SNPs TSV.
- `--output`: output TSV.
- `--allow-strains`: strain prefixes to include.

### `scripts/summarize_hpv16_e6e7_variants.py`
Purpose: Summarize HPV16 E6/E7 variants across samples, Cambodia accessions,
lineages, and a reference, emitting compact per-ID variant lists. Used for
reporting and comparisons.
Key CLI parameters:
- `--sample-effects`: sample E6/E7 variant effects TSV.
- `--cambodia-snps`: Cambodia SNPs TSV.
- `--lineage-snps`: lineage SNPs TSV.
- `--sample-list`: metadata TSV with sample IDs.
- `--cambodia-fasta`: Cambodian HPV16 FASTA.
- `--lineage-fasta`: HPV16 lineage FASTA.
- `--ref-fasta`: reference FASTA.
- `--bed-dir`: directory with E6/E7 BED files.
- `--output`: output TSV path.

## Phylogenetic tree preparation

### `scripts/hpv16_select_ncbi_genomes.sh`
Purpose: Select and rename HPV16 NCBI Virus genomes for phylogenetic trees.
Creates/uses a user-edited TSV of selected accessions.
Key CLI parameters:
- `--init-selection`: create a starter selection TSV and exit.
- `<ncbi_tsv>` / `<ncbi_fasta>`: NCBI Virus metadata + FASTA.
- `<selected_tsv>` / `<selected_fasta>`: selection TSV and extracted FASTA.
- `<selected_renamed_fasta>`: FASTA with country/lineage prefixes.
Environment overrides:
- `NCBI_ACC_COL`, `NCBI_COUNTRY_COL`, `SELECTED_ACC_COL`, `SELECTED_PREFIX_COL`, `SKIP_ID`.

### `scripts/hpv18_select_ncbi_genomes.sh`
Purpose: Select and rename HPV18 NCBI Virus genomes using a two-step selection
workflow (acc+country table, then selected subset).
Key CLI parameters:
- `--init-selection`: create the selection TSV and exit.
- `<ncbi_tsv>` / `<ncbi_fasta>`: NCBI Virus metadata + FASTA.
- `<acc_country_tsv>`: full accession/country table.
- `<acc_country_selected_tsv>`: edited selection table.
- `<selected_fasta>` / `<selected_renamed_fasta>`: output FASTAs.
Environment overrides:
- `ACCESSION_COL`, `COUNTRY_COL`, `SKIP_ID`.

### `scripts/hpv16_extract_lineages_fasta.sh`
Purpose: Extract lineage reference sequences from the HPV16 NCBI FASTA.
Key CLI parameters:
- `<lineages_tsv>`: lineage metadata TSV (accession column).
- `<ncbi_fasta>`: HPV16 NCBI FASTA.
- `<output_fasta>`: extracted FASTA.
- `[accession_col]`: accession column in the TSV (default 6).

### `scripts/hpv18_extract_lineages_fasta.sh`
Purpose: Extract lineage reference sequences from the HPV18 NCBI FASTA.
Key CLI parameters:
- `<lineages_tsv>`: lineage metadata TSV (accession column).
- `<ncbi_fasta>`: HPV18 NCBI FASTA.
- `<output_fasta>`: extracted FASTA.
- `[accession_col]`: accession column in the TSV (default 6).

### `scripts/rename_lineages.py`
Purpose: Rename FASTA headers using metadata TSV columns (e.g., prefix with
country or lineage). Used by the HPV16/18 selection scripts.
Key CLI parameters:
- `<metadata_tsv>`: TSV with accession and prefix columns.
- `<accession>` / `<prefix>`: 1-based column indices for accession/prefix.
- `<input_fasta>` / `<output_fasta>`: input and renamed FASTA.
- `--verbose` / `--quiet`: logging control.

### `scripts/fix_msa_formatting.py`
Purpose: Simplify FASTA headers in alignments to be compatible with
`virstrain_build` by truncating after the first `|` or `,`.
Key CLI parameters:
- `<msa>`: input FASTA alignment.

### `scripts/assign_hpv18_lineages.py`
Purpose: Assign HPV18 lineage labels to tree tips based on distance to
reference tips in a tree. Used to annotate tree outputs.
Key CLI parameters:
- `treefile`: input Newick tree.
- `--refs-file`: TSV of lineage -> reference tip ID (default from metadata).
- `--outgroups-file`: list of outgroup tips (default from metadata).

### `scripts/hpv16_prepare_samples.sh`
Purpose: Build HPV16 consensus sequences for samples (for tree inputs) using
BCF outputs from the mapping step and the PAVE reference FASTA.
Key CLI parameters (via environment):
- `OUT_DIR`: required output directory for consensus FASTAs.
- `PAVE_FASTA`: path to PAVE FASTA (defaults inside repo).
- `BCF_DIR` / `BCF_RUN_ID`: where to find per-sample BCFs.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: which samples to process.

### `scripts/hpv18_prepare_samples.sh`
Purpose: Build HPV18 consensus sequences for samples (for tree inputs) using
BCF outputs and the PAVE reference FASTA, plus strains.tsv for sample detection.
Key CLI parameters (via environment):
- `OUT_DIR`: required output directory for consensus FASTAs.
- `PAVE_FASTA`, `HPV18REF_FASTA`: reference FASTA locations.
- `BCF_DIR` / `BCF_RUN_ID`: where to find per-sample BCFs.
- `SAMPLES` / `SAMPLES_FILE` / `SAMPLES_TSV`: which samples to process.
- `STRAINS_TSV`: strains table used to infer HPV18 samples when `SAMPLES` is empty.

### `scripts/extract_country_sequences.py`
Purpose: Extract sequences from a selected FASTA for a specific country, used
for Cambodia-focused SNP comparisons.
Key CLI parameters:
- `--selected-fasta`: FASTA with selected accessions.
- `--selected-metadata`: TSV with accession + country columns.
- `--country`: country name to filter.
- `--label-prefix`: optional prefix added to output IDs.
- `--output`: output FASTA path.
