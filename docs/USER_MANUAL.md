# User Manual

This manual explains how to prepare inputs, configuration, and reference data
before running the analyses in this repository.

## 1) Prerequisites

- Nextflow available in `PATH` (Java 17+ is required by Nextflow).
- Conda available in `PATH` (pipelines use per‑process Conda environments).
- Basic UNIX tools (`bash`, `coreutils`).

## 2) Repository layout (what goes where)

- `input/`: symlinks or folders pointing to raw FASTQ data (not tracked in git).
- `metadata/`: sample sheets and other fixed inputs (TSV files).
- `config/`: user-editable pipeline configs (base + step-specific) and MultiQC configs.
- `pipelines/config/`: technical Nextflow config (executor/conda wiring).
- `pipelines/conda_env/`: Conda environment definitions used by pipelines.
- `pipelines/multiqc/`: MultiQC configuration files used by pipelines.
- `refdata/raw/`: reference inputs from external sources (PAVE FASTA/GFF3, NCBI downloads).
- `refdata/derived/`: derived reference data (feature tables, renamed/filtered FASTA sets).
- `analysis-input1/` and `analysis-input2/`: outputs and reports for each analysis.
- `docs/`: technical documentation and this user manual.

## 3) Prepare raw input data (`input/`)

Put or link each sequencing run folder under `input/`. Examples:

- If your runs are organized as `.../RUN_ID/Fastq/`, put the run under `input/RUN_ID/`.
- If FASTQs are directly under the run directory, put them under `input/RUN_ID/`.

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
  - `config/general.config`: all user-editable pipeline parameters (Centrifuge index/taxdump, PAVE reference names, Cambodia defaults, tree defaults, and shared threads)
- Step‑specific path configs (inputs/outputs) are stored under `bin/config/` and are not typically edited by users:
  - `bin/config/analysis-input1_001.centrifuge.config`
  - `bin/config/analysis-input1_002.bowtie_vs_pave.config`
  - `bin/config/analysis-input1_003.virstrain.config`
  - `bin/config/analysis-input2_001.bucketing.config`
  - `bin/config/analysis-input2_002.mapping_vs_pave.config`
  - `bin/config/analysis-input2_003.hpv16_tree.config`
  - `bin/config/analysis-input2_004.hpv18_tree.config`
  - `bin/config/analysis-input2_005.snps_samples_vs_db.config`
- Gene‑mapping step configs are under `bin/config/` (`bin/config/pave_e6.config`, `bin/config/pave_e7.config`).
- Tree defaults are configured via `config/general.config`.

Technical Nextflow settings (executor/conda wiring and derived refdata paths) live under `pipelines/config/`.
Conda environments are defined under `pipelines/conda_env/`.
MultiQC configs are under `pipelines/multiqc/`.

## 6) Prepare reference data (`refdata/`)

### 6.1 PAVE reference (raw)

Place the PAVE reference FASTA (and gene FASTAs if used) under `refdata/raw/pave/`.
If you use variant effect annotation, place the PAVE GFF3 files under
`refdata/raw/pave/gff3/` (one GFF3 per reference sequence).

BED files used for E6/E7 SNP extraction are derived from the GFF3 inputs and
stored under `refdata/derived/pave/bed/` (see below).

These paths are wired via the technical pipeline configs (under `pipelines/config/`).

### 6.2 PAVE feature tables (derived)

Coverage statistics use tabular feature files (TSV) derived from the PAVE GFF3s.
Generate them with:

```
scripts/gff3_to_features_tsv.run_all.sh \
  refdata/raw/pave/gff3 \
  refdata/derived/pave/features_tsv
```

These TSVs are consumed by the Bowtie vs PAVE steps (coverage summaries).
If the directory is missing or empty, the pipeline will generate it automatically.

### 6.2b PAVE BED files (derived)

E6/E7 SNP extraction uses BED intervals derived from the same GFF3 inputs.
Generate them with:

```
scripts/gff3_to_bed.run_all.sh \
  refdata/raw/pave/gff3 \
  refdata/derived/pave/bed
```

These BED files are required by the Bowtie vs PAVE and SNPs samples vs database steps.

### 6.3 Phylogenetic tree inputs (raw + derived)

Place raw inputs under:

- `refdata/raw/hpv16_tree`
- `refdata/raw/hpv18_tree`

Derived tree inputs live under:

- `refdata/derived/hpv16_tree`
- `refdata/derived/hpv18_tree`

The preparation steps for these (including the shared lineage reference
FASTA files used by step 002 SNP‑to‑lineage comparison) are described in the
repository root `README.md`.

### 6.4 Centrifuge database (taxonomic index)

Build or provide a Centrifuge database and taxonomy dump. A helper script is
included:

```
scripts/build_centrifuge_db.sh \
  --outdir refdata/centrifuge \
  --index-name human_abv \
  --threads 24
```

Then update `config/general.config`, for example:

- `index = "refdata/centrifuge/human_abv"`
- `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

By default the script builds an index that includes human plus RefSeq
archaea/bacteria/viral. If you need a different composition, pass
`--refseq-domains` (e.g., `--refseq-domains viral`).

## 7) Run the analyses

After the preparation steps above, run the analyses using the wrapper scripts
listed in the repository root `README.md`.
