# User Manual

This manual explains how to prepare inputs, configuration, and reference data
before running the analyses in this repository.

## 1) Prerequisites

- Nextflow available in `PATH` (Java 17+ is required by Nextflow).
- Conda available in `PATH` (pipelines use per‑process Conda environments).
- Basic UNIX tools (`bash`, `coreutils`).

## 2) Repository layout (what goes where)

- `input_reads/`: symlinks or folders pointing to raw FASTQ data (not tracked in git).
- `metadata/`: sample sheets and other fixed inputs (TSV files).
- `config/`: user-editable pipeline configs (base + step-specific).
- `config/pipelines/`: technical Nextflow config (executor/conda wiring, derived paths).
- `pipelines/conda_env/`: Conda environment definitions used by pipelines.
- `pipelines/multiqc/`: MultiQC configuration files used by pipelines.
- `refdata/`: reference inputs from external sources (PAVE FASTA/GFF3, NCBI downloads).
- `derived_data/`: generated intermediate assets.
  - `derived_data/refdata/`: derived reference data (feature tables, renamed/filtered FASTA sets).
- `derived_data/indices/`: shared Bowtie/VirStrain indices (Bowtie index + preliminary VirStrain index).
- `prelim_analysis/` and `targeted_analysis/`: outputs and reports for each analysis.
- `docs/`: technical documentation and this user manual.

## 3) Prepare raw input data (`input_reads/`)

Put or link each sequencing run folder under `input_reads/`. Examples:

- If your runs are organized as `.../RUN_ID/Fastq/`, put the run under `input_reads/RUN_ID/`.
- If FASTQs are directly under the run directory, put them under `input_reads/RUN_ID/`.

These paths are referenced in the sample sheets (next section).

## 4) Prepare sample sheets (`metadata/`)

Sample sheets define which runs and samples to process:

- `metadata/samples-input1.tsv`
- `metadata/samples-input2.tsv`

Each row should include the run ID, sample ID, FASTQ directory (relative to the
repo root), and the `fastq_sample_id` (the exact prefix used in FASTQ filenames).
If a run uses a flat FASTQ layout, point to the run folder directly. If it has a
`Fastq/` subdirectory, point to that.

`sample_id` is the normalized identifier used in outputs (e.g., `KHCA-064`,
`HPV-019`). `fastq_sample_id` preserves the original naming found in the FASTQ
files (e.g., `KHCA064`, `HPV019`, `HVP-110`) so the pipelines can locate reads
even when the raw file prefix differs from the normalized ID.

## 5) Configure pipelines (`config/`)

User-editable pipeline parameters live in `config/`. Edit these files to point
to your local reference data paths and to set resource limits:

- Base pipeline config:
  - `config/user.config`: all user-editable pipeline parameters (Centrifuge index/taxdump, PAVE reference names, target-country defaults, tree defaults, and shared threads)
- Step‑specific path configs (inputs/outputs) are stored under `config/analyses/` and are not typically edited by users:
  - `config/analyses/prelim_analysis.config`
  - `config/analyses/targeted_analysis.config`
- Tree defaults are configured via `config/user.config`.

Technical Nextflow settings (executor/conda wiring and derived refdata paths) live under `config/pipelines/`.
Conda environments are defined under `pipelines/conda_env/`.
MultiQC configs are under `pipelines/multiqc/`.

## 6) Prepare reference data (`refdata/`)

### 6.1 PAVE reference (raw)

Place the PAVE reference FASTA (and gene FASTAs if used) under `refdata/pave/`.
If you use variant effect annotation, place the PAVE GFF3 files under
`refdata/pave/gff3/` (one GFF3 per reference sequence).

BED files used for E6/E7 SNP extraction are derived from the GFF3 inputs and
stored under `derived_data/refdata/pave/bed/` (see below).

These paths are wired via the technical pipeline configs (under `config/pipelines/`).

### 6.2 PAVE feature tables (derived)

Coverage statistics use tabular feature files (TSV) derived from the PAVE GFF3s.
Generate them with:

```
scripts/pave/gff3_to_features_tsv.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/features_tsv
```

These TSVs are consumed by the Bowtie vs PAVE steps (coverage summaries).
If the directory is missing or empty, the pipeline will generate it automatically.

### 6.2b PAVE BED files (derived)

E6/E7 SNP extraction uses BED intervals derived from the same GFF3 inputs.
Generate them with:

```
scripts/pave/gff3_to_bed.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/bed
```

These BED files are required by the Bowtie vs PAVE and SNPs samples vs database steps.
If the directory is missing or empty, the pipelines will generate it automatically.

### 6.3 Phylogenetic tree inputs (raw + derived)

Place raw inputs under:

- `refdata/hpv16_tree`
- `refdata/hpv18_tree`

Derived tree inputs live under:

- `derived_data/refdata/hpv16_tree`
- `derived_data/refdata/hpv18_tree`

The preparation steps below include the shared lineage reference FASTA files
used by the step 02 SNP‑to‑lineage comparison.

Tools needed for the preparation commands below:
- `seqkit`
- `bcftools`
- Python 3 with `biopython`, `docopt`, `loguru`

#### Lineage reference preparation (shared)

HPV16:

```
scripts/phylo_tree/hpv16_extract_lineages_fasta.sh \
  refdata/hpv16_tree/HPV16_lineages.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  derived_data/refdata/hpv16_tree/lineages_ref.fasta

python3 scripts/phylo_tree/rename_lineages.py \
  refdata/hpv16_tree/HPV16_lineages.tsv 6 4 \
  derived_data/refdata/hpv16_tree/lineages_ref.fasta \
  derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta
```

HPV18:

```
scripts/phylo_tree/hpv18_extract_lineages_fasta.sh \
  refdata/hpv18_tree/HPV18_lineages.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  derived_data/refdata/hpv18_tree/lineages_ref.fasta

python3 scripts/phylo_tree/rename_lineages.py \
  refdata/hpv18_tree/HPV18_lineages.tsv 6 4 \
  derived_data/refdata/hpv18_tree/lineages_ref.fasta \
  derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta
```

#### HPV16 tree

1) Place these files under `refdata/hpv16_tree/`:
   - `HPV16_lineages.tsv`
   - `HPV16-NCBIVirus.fasta`
   - `HPV16-NCBIVirus.tsv`

2) Place prepared inputs under `derived_data/refdata/hpv16_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```
scripts/phylo_tree/hpv16_select_ncbi_genomes.sh --init-selection \
  refdata/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  derived_data/refdata/hpv16_tree/selected \
  derived_data/refdata/hpv16_tree/selected.fasta \
  derived_data/refdata/hpv16_tree/selected_renamed.fasta

# Edit derived_data/refdata/hpv16_tree/selected, then re-run without --init-selection:
scripts/phylo_tree/hpv16_select_ncbi_genomes.sh \
  refdata/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  derived_data/refdata/hpv16_tree/selected \
  derived_data/refdata/hpv16_tree/selected.fasta \
  derived_data/refdata/hpv16_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 02). Set your sample IDs explicitly:

```
OUT_DIR=derived_data/refdata/hpv16_tree \
SAMPLES="<space-separated sample IDs>" \
scripts/phylo_tree/hpv16_prepare_samples.sh
```

The mapping run ID is inferred from `metadata/samples-input2.tsv` (using the
`fastq_dir` column). Override with `BCF_RUN_ID=...` or `BCF_DIR=...` if needed.

5) Run the tree pipeline:

```
bin/targeted_analysis.steps/04.hpv16_tree.run.sh
```

#### HPV18 tree

1) Place these files under `refdata/hpv18_tree/`:
   - `HPV18_lineages.tsv`
   - `HPV18-NCBIVirus.fasta`
   - `HPV18-NCBIVirus.tsv`

2) Place prepared inputs under `derived_data/refdata/hpv18_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```
scripts/phylo_tree/hpv18_select_ncbi_genomes.sh --init-selection \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  derived_data/refdata/hpv18_tree/selected.fasta \
  derived_data/refdata/hpv18_tree/selected_renamed.fasta

# Edit derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then re-run without --init-selection:
scripts/phylo_tree/hpv18_select_ncbi_genomes.sh \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  derived_data/refdata/hpv18_tree/selected.fasta \
  derived_data/refdata/hpv18_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 02). By default the script
derives samples from `targeted_analysis/02.mapping_vs_pave/reports/strains.tsv`
by selecting rows with top strain `HPV18` for the run ID:

```
OUT_DIR=derived_data/refdata/hpv18_tree \
scripts/phylo_tree/hpv18_prepare_samples.sh
```

The mapping run ID is inferred from `metadata/samples-input2.tsv` (using the
`fastq_dir` column). Override with `BCF_RUN_ID=...` or `BCF_DIR=...` if needed.

5) Run the tree pipeline:

```
bin/targeted_analysis.steps/05.hpv18_tree.run.sh
```

### 6.4 Centrifuge database (taxonomic index)

Build or provide a Centrifuge database and taxonomy dump. A helper script is
included:

```
scripts/taxonomy_assignment/build_centrifuge_db.sh \
  --outdir refdata/centrifuge \
  --index-name human_abv \
  --threads 24
```

Then update `config/user.config`, for example:

- `index = "refdata/centrifuge/human_abv"`
- `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

By default the script builds an index that includes human plus RefSeq
archaea/bacteria/viral. If you need a different composition, pass
`--refseq-domains` (e.g., `--refseq-domains viral`).

## 7) Run the analyses

After the preparation steps above, run the analyses using the wrapper scripts below.

### 7.1 prelim_analysis

All steps in one go:

```
bin/prelim_analysis.run.sh
```

Or run each step individually:

```
bin/prelim_analysis.steps/01.bucketing.run.sh
bin/prelim_analysis.steps/02.mapping_vs_pave.run.sh
bin/prelim_analysis.steps/03.variant_analysis.run.sh
bin/prelim_analysis.steps/04.virstrain.run.sh --run-virstrain
```

Step 01 report (MultiQC):

`prelim_analysis/01.bucketing/reports/multiqc_report.html`

VirStrain (step 05) is optional and does not run unless you pass
`--run-virstrain` to the wrapper:

```
bin/prelim_analysis.run.sh --run-virstrain
```

### 7.2 targeted_analysis

All steps in one go:

```
bin/targeted_analysis.run.sh
```

Or run each step individually:

```
bin/targeted_analysis.steps/01.bucketing.run.sh
bin/targeted_analysis.steps/02.mapping_vs_pave.run.sh
bin/targeted_analysis.steps/03.variant_analysis.run.sh
bin/targeted_analysis.steps/04.hpv16_tree.run.sh
bin/targeted_analysis.steps/05.hpv18_tree.run.sh
```

### 7.3 Run a single sample (optional)

Some steps provide a `run_sample.sh` wrapper under `bin/*steps/single_sample/` for
running one sample pair. The third argument is an output prefix used to infer
`run_id` and `sample_id`; outputs still go to the step output directory configured
in `config/`.

```
bin/prelim_analysis.steps/single_sample/02.mapping_vs_pave.run_sample.sh \
  /path/to/SAMPLE_R1.fastq.gz /path/to/SAMPLE_R2.fastq.gz \
  prelim_analysis/02.mapping_vs_pave/output/RUN_ID/SAMPLE
```

## 8) Troubleshooting

If Nextflow fails to start because of Java, create and activate the provided
Java environment:

```
conda env create -f pipelines/conda_env/nextflow_java.env.yml
conda activate nextflow-java
```

If Nextflow behaves differently when Conda is activated in your shell, try
`conda deactivate` and run Nextflow again.

### Resume after a failure

Re-run the same command with `-resume`:

```
bin/prelim_analysis.steps/02.mapping_vs_pave.run.sh -resume
```
