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
- `config/`: pipeline configuration files and Conda env definitions.
- `refdata/`: curated reference data (PAVE reference, phylogenetic inputs, feature tables).
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

Each row should include the run ID, sample ID, and the FASTQ directory (relative
to the repo root). If a run uses a flat FASTQ layout, point to the run folder
directly. If it has a `Fastq/` subdirectory, point to that.

## 5) Configure pipelines (`config/`)

All pipeline parameters live in `config/`. Edit these files to point to your
local reference data paths and to set resource limits:

- `config/centrifuge_bucketing.config`: Centrifuge index + taxonomy paths
- `config/bowtie_vs_pave.config`: PAVE reference + features + BED/GFF3 dirs for variant annotation
- `config/virstrain.config`: VirStrain index paths
- `config/pave_e6.config`, `config/pave_e7.config`: gene‑level mapping configs
- `config/hpv16_tree.config`, `config/hpv18_tree.config`: tree pipeline inputs

Conda environments used by pipelines are also defined here (e.g.
`config/centrifuge_bucketing.env.yml`).

## 6) Prepare reference data (`refdata/`)

### 6.1 PAVE reference

Place the PAVE reference FASTA and feature tables under `refdata/` as required
by `config/bowtie_vs_pave.config` and the gene‑level configs.

If you use variant effect annotation in step 002, place the PAVE GFF3 files
under `refdata/gff3` (one GFF3 per reference sequence).

### 6.2 Phylogenetic tree inputs

Place curated tree inputs under:

- `refdata/hpv16_tree`
- `refdata/hpv18_tree`

The preparation steps for these are described in the repository root
`README.md`.

### 6.3 Centrifuge database (taxonomic index)

Build or provide a Centrifuge database and taxonomy dump. A helper script is
included:

```
scripts/build_centrifuge_db.sh \
  --outdir refdata/centrifuge \
  --index-name human_abv \
  --threads 24
```

Then update `config/centrifuge_bucketing.config`, for example:

- `index = "refdata/centrifuge/human_abv"`
- `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

By default the script builds an index that includes human plus RefSeq
archaea/bacteria/viral. If you need a different composition, pass
`--refseq-domains` (e.g., `--refseq-domains viral`).

## 7) Run the analyses

After the preparation steps above, run the analyses using the wrapper scripts
listed in the repository root `README.md`.
