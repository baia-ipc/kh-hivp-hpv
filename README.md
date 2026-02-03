# Kh_HIVp_HPV

This repository contains a reproducible workflow that we used for
the analysis of HPV sequencing data in our study.

## Analyses

Two sets of analyses are contained. The first (`preliminary-analysis-all-patients`) contains an analysis of
all 64 patients (and some controls), based on the first 3 Miseq runs. After that, we followed with an deeper sequencing
analysis of the patients for which the first analysis and the GenExpert results indicated infection with HPV16 and
HPV18 (`targeted-analysis-hpv16-hpv18`).

To run the analysis:
- the input readsets must be copied or linked into the `input` directory
- raw reference data must be copied or linked into the `refdata` directory (derived assets live under `intermediate_files/`)
- Nextflow and Conda must be installed on the system
- the scripts `bin/preliminary-analysis-all-patients.run.sh` and/or
  `bin/targeted-analysis-hpv16-hpv18.run.sh` must be run

A detailed user manual is available under `docs/USER_MANUAL.md`


## Repository layout (high level)

- `preliminary-analysis-all-patients/`: analysis for the first input dataset (all patients)
- `targeted-analysis-hpv16-hpv18/`: analysis for the second input dataset (HPV16/18-focused)
- `pipelines/`: Nextflow pipelines
  - `pipelines/conda_env/`: Conda environment definitions used by pipelines
  - `pipelines/multiqc/`: MultiQC config files used by pipelines
- `config/`: user-editable configuration (pipeline + step configs)
  - `config/user.config`: shared user parameters (indices, tree defaults, etc.)
  - `config/bin/`: step path configs (profiles used by wrapper scripts)
  - `config/pipelines/`: technical Nextflow config (executor/conda wiring, derived paths)
- `metadata/`: sample lists and other fixed inputs (e.g. bucket taxonomy IDs)
- `refdata/`: external reference inputs (PAVE FASTA/GFF3, NCBI downloads)
- `intermediate_files/`: generated intermediate assets
  - `intermediate_files/refdata/`: derived reference data (feature tables, renamed/filtered FASTA sets)
  - `intermediate_files/indices/`: bowtie/virstrain indices
- `bin/`: step and analysis runner scripts (wrappers around Nextflow)
  - `bin/*steps/`: per-step wrappers
  - `bin/*steps/single_sample/`: single-sample wrappers for supported steps

## Requirements

- Nextflow installed and available in `PATH`; Java 17+ (required by Nextflow)

- Conda installed and available in `PATH` (pipelines use per-process Conda
  environments)

## Configuration you may need to edit

- `metadata/samples-input1.tsv` and `metadata/samples-input2.tsv`: which samples to process and where the FASTQs are. These include a normalized `sample_id` plus `fastq_sample_id` (the exact prefix found in FASTQ filenames) used for read discovery.
- `config/user.config`: all user-editable pipeline parameters (Centrifuge index/taxdump, PAVE reference names, Cambodia settings, tree defaults, and shared threads)
- Step path configs under `bin/config/` are internal defaults (profiled per step) and generally not edited by users.
- Derived reference paths are wired in pipeline technical configs under `config/pipelines/` (not user-edited).

## How to run preliminary-analysis-all-patients

Run these commands from the repository root.

All steps in one go:

```bash
bin/preliminary-analysis-all-patients.run.sh
```

Or run each step individually:

```bash
bin/preliminary-analysis-all-patients.steps/001.0.centrifuge.run.sh
bin/preliminary-analysis-all-patients.steps/002.0.bowtie_vs_pave.run.sh
bin/preliminary-analysis-all-patients.steps/003.0.virstrain.run.sh
bin/preliminary-analysis-all-patients.steps/004.0.bowtie_vs_pave.E6.run.sh
bin/preliminary-analysis-all-patients.steps/005.0.bowtie_vs_pave.E7.run.sh
```

## User manual

See `docs/USER_MANUAL.md` for a full setup guide (inputs, configs, reference data,
and database creation).

### Step 001 report (MultiQC)

After running step 001, open the interactive report at:

`preliminary-analysis-all-patients/001.0.centrifuge/reports/multiqc_report.html`

### Run a single sample (optional)

Some steps also provide a `run_sample.sh` wrapper under `bin/*steps/single_sample/` for running one sample pair.
The third argument is an output prefix used to infer `run_id` and `sample_id`; outputs still go to the step output directory configured in `config/`.

```bash
bin/preliminary-analysis-all-patients.steps/single_sample/002.0.bowtie_vs_pave.run_sample.sh \
  /path/to/SAMPLE_R1.fastq.gz /path/to/SAMPLE_R2.fastq.gz \
  preliminary-analysis-all-patients/002.0.bowtie_vs_pave/output/RUN_ID/SAMPLE
```

## How to run targeted-analysis-hpv16-hpv18

Run these commands from the repository root.

All steps in one go:

```bash
bin/targeted-analysis-hpv16-hpv18.run.sh
```

Or run each step individually:

```bash
bin/targeted-analysis-hpv16-hpv18.steps/001.0.bucketing.run.sh
bin/targeted-analysis-hpv16-hpv18.steps/002.0.mapping_vs_pave.run.sh
bin/targeted-analysis-hpv16-hpv18.steps/003.0.hpv16_tree.run.sh
bin/targeted-analysis-hpv16-hpv18.steps/004.0.hpv18_tree.run.sh
bin/targeted-analysis-hpv16-hpv18.steps/005.0.snps_samples_vs_db.run.sh
```

### Phylogenetic trees (HPV16 and HPV18)

The tree steps require raw reference inputs under `refdata/` and
prepared (derived) inputs under `intermediate_files/refdata/`. They also use the
mapping outputs from step 002 to build consensus sequences.

Tools needed for the preparation commands below:
- `seqkit`
- `bcftools`
- Python 3 with `biopython`, `docopt`, `loguru`

#### Lineage reference preparation (shared)

These lineage reference FASTAs are used both by the phylogenetic trees and by
the SNP‑to‑lineage comparison in step 002.

HPV16:

```bash
scripts/hpv16_extract_lineages_fasta.sh \
  refdata/hpv16_tree/HPV16_lineages.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  intermediate_files/refdata/hpv16_tree/lineages_ref.fasta

python3 scripts/rename_lineages.py \
  refdata/hpv16_tree/HPV16_lineages.tsv 6 4 \
  intermediate_files/refdata/hpv16_tree/lineages_ref.fasta \
  intermediate_files/refdata/hpv16_tree/lineages_ref_renamed.fasta
```

HPV18:

```bash
scripts/hpv18_extract_lineages_fasta.sh \
  refdata/hpv18_tree/HPV18_lineages.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  intermediate_files/refdata/hpv18_tree/lineages_ref.fasta

python3 scripts/rename_lineages.py \
  refdata/hpv18_tree/HPV18_lineages.tsv 6 4 \
  intermediate_files/refdata/hpv18_tree/lineages_ref.fasta \
  intermediate_files/refdata/hpv18_tree/lineages_ref_renamed.fasta
```

#### HPV16 tree

1) Place these files under `refdata/hpv16_tree/`:
   - `HPV16_lineages.tsv`
   - `HPV16-NCBIVirus.fasta`
   - `HPV16-NCBIVirus.tsv`

2) Place prepared inputs under `intermediate_files/refdata/hpv16_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```bash
scripts/hpv16_select_ncbi_genomes.sh --init-selection \
  refdata/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  intermediate_files/refdata/hpv16_tree/selected \
  intermediate_files/refdata/hpv16_tree/selected.fasta \
  intermediate_files/refdata/hpv16_tree/selected_renamed.fasta

# Edit intermediate_files/refdata/hpv16_tree/selected, then re-run without --init-selection:
scripts/hpv16_select_ncbi_genomes.sh \
  refdata/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/hpv16_tree/HPV16-NCBIVirus.fasta \
  intermediate_files/refdata/hpv16_tree/selected \
  intermediate_files/refdata/hpv16_tree/selected.fasta \
  intermediate_files/refdata/hpv16_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 002). Set your sample IDs explicitly:

```bash
OUT_DIR=intermediate_files/refdata/hpv16_tree \
SAMPLES="<space-separated sample IDs>" \
scripts/hpv16_prepare_samples.sh
```

The mapping run ID is inferred from `metadata/samples-input2.tsv` (using the
`fastq_dir` column). Override with `BCF_RUN_ID=...` or `BCF_DIR=...` if needed.

5) Run the tree pipeline:

```bash
bin/targeted-analysis-hpv16-hpv18.steps/003.0.hpv16_tree.run.sh
```

#### HPV18 tree

1) Place these files under `refdata/hpv18_tree/`:
   - `HPV18_lineages.tsv`
   - `HPV18-NCBIVirus.fasta`
   - `HPV18-NCBIVirus.tsv`

2) Place prepared inputs under `intermediate_files/refdata/hpv18_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```bash
scripts/hpv18_select_ncbi_genomes.sh --init-selection \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  intermediate_files/refdata/hpv18_tree/selected.fasta \
  intermediate_files/refdata/hpv18_tree/selected_renamed.fasta

# Edit intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then re-run without --init-selection:
scripts/hpv18_select_ncbi_genomes.sh \
  refdata/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  intermediate_files/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  intermediate_files/refdata/hpv18_tree/selected.fasta \
  intermediate_files/refdata/hpv18_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 002). By default the script
derives samples from `targeted-analysis-hpv16-hpv18/002.0.mapping_vs_pave/reports/strains.tsv`
by selecting rows with top strain `HPV18` for the run ID:

```bash
OUT_DIR=intermediate_files/refdata/hpv18_tree \
scripts/hpv18_prepare_samples.sh
```

The mapping run ID is inferred from `metadata/samples-input2.tsv` (using the
`fastq_dir` column). Override with `BCF_RUN_ID=...` or `BCF_DIR=...` if needed.

5) Run the tree pipeline:

```bash
bin/targeted-analysis-hpv16-hpv18.steps/004.0.hpv18_tree.run.sh
```

## Troubleshooting

If Nextflow fails to start because of Java, create and activate the provided
Java environment:

```bash
conda env create -f pipelines/conda_env/nextflow_java.env.yml
conda activate nextflow-java
```

If Nextflow behaves differently when Conda is activated in your shell, try
`conda deactivate` and run Nextflow again.

### Resume after a failure

Re-run the same command with `-resume`:

```bash
bin/preliminary-analysis-all-patients.steps/002.0.bowtie_vs_pave.run.sh -resume
```
