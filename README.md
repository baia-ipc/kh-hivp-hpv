# Kh_HIVp_HPV

This repository contains a reproducible workflow that we used for
the analysis of HPV sequencing data in our study.

## Repository layout (high level)

- `analysis-input1/`: analysis for the first input dataset (all patients)
- `analysis-input2/`: analysis for the second input dataset (HPV16/18-focused)
- `pipelines/`: Nextflow pipelines
  - `pipelines/config/`: technical Nextflow config
  - `pipelines/conda_env/`: Conda environment definitions used by pipelines
- `config/`: user-editable configuration files (pipeline + step configs, MultiQC)
- `metadata/`: sample lists and other fixed inputs (e.g. bucket taxonomy IDs)
- `refdata/raw/`: external reference inputs (PAVE FASTA/GFF3, NCBI downloads)
- `refdata/derived/`: derived reference data (feature tables, renamed/filtered FASTA sets)

## Requirements

- Nextflow installed and available in `PATH`; Java 17+ (required by Nextflow)

- Conda installed and available in `PATH` (pipelines use per-process Conda
  environments)

## Configuration you may need to edit

- `metadata/samples-input1.tsv` and `metadata/samples-input2.tsv`: which samples to process and where the FASTQs are. These include a normalized `sample_id` plus `fastq_sample_id` (the exact prefix found in FASTQ filenames) used for read discovery.
- `config/centrifuge_bucketing.config`: Centrifuge index/taxdump paths and resource settings
- `config/bowtie_vs_pave.config`: PAVE reference paths and resource settings
- Step-specific configs (e.g. `config/analysis-input1_001.centrifuge.config`) set per-step inputs/outputs.

## How to run analysis-input1

Run these commands from the repository root.

```bash
analysis-input1/001.0.centrifuge/scripts/run_all.sh
analysis-input1/002.0.bowtie_vs_pave/scripts/run_all.sh
analysis-input1/003.0.virstrain/scripts/run_all.sh
analysis-input1/004.0.bowtie_vs_pave.E6/scripts/run_all.sh
analysis-input1/005.0.bowtie_vs_pave.E7/scripts/run_all.sh
```

## User manual

See `docs/USER_MANUAL.md` for a full setup guide (inputs, configs, reference data,
and database creation).

### Step 001 report (MultiQC)

After running step 001, open the interactive report at:

`analysis-input1/001.0.centrifuge/reports/multiqc_report.html`

### Run a single sample (optional)

Some steps also provide a `run.sh` wrapper for running one sample pair.
The third argument is an output prefix used to infer `run_id` and `sample_id`; outputs still go to the step output directory configured in `config/`.

```bash
analysis-input1/002.0.bowtie_vs_pave/scripts/run.sh \
  /path/to/SAMPLE_R1.fastq.gz /path/to/SAMPLE_R2.fastq.gz \
  analysis-input1/002.0.bowtie_vs_pave/output/RUN_ID/SAMPLE
```

## How to run analysis-input2

Run these commands from the repository root.

```bash
analysis-input2/001.0.bucketing/scripts/run_all.sh
analysis-input2/002.0.mapping_vs_pave/scripts/run_all.sh
analysis-input2/005.0.cambodia_snps/scripts/run_all.sh
```

### Phylogenetic trees (HPV16 and HPV18)

The tree steps require raw reference inputs under `refdata/raw/` and
prepared (derived) inputs under `refdata/derived/`. They also use the
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
  refdata/raw/hpv16_tree/HPV16_lineages.tsv \
  refdata/raw/hpv16_tree/HPV16-NCBIVirus.fasta \
  refdata/derived/hpv16_tree/lineages_ref.fasta

python3 scripts/rename_lineages.py \
  refdata/raw/hpv16_tree/HPV16_lineages.tsv 6 4 \
  refdata/derived/hpv16_tree/lineages_ref.fasta \
  refdata/derived/hpv16_tree/lineages_ref_renamed.fasta
```

HPV18:

```bash
scripts/hpv18_extract_lineages_fasta.sh \
  refdata/raw/hpv18_tree/HPV18_lineages.tsv \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/derived/hpv18_tree/lineages_ref.fasta

python3 scripts/rename_lineages.py \
  refdata/raw/hpv18_tree/HPV18_lineages.tsv 6 4 \
  refdata/derived/hpv18_tree/lineages_ref.fasta \
  refdata/derived/hpv18_tree/lineages_ref_renamed.fasta
```

#### HPV16 tree

1) Place these files under `refdata/raw/hpv16_tree/`:
   - `HPV16_lineages.tsv`
   - `HPV16-NCBIVirus.fasta`
   - `HPV16-NCBIVirus.tsv`

2) Place prepared inputs under `refdata/derived/hpv16_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```bash
scripts/hpv16_select_ncbi_genomes.sh --init-selection \
  refdata/raw/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/raw/hpv16_tree/HPV16-NCBIVirus.fasta \
  refdata/derived/hpv16_tree/selected \
  refdata/derived/hpv16_tree/selected.fasta \
  refdata/derived/hpv16_tree/selected_renamed.fasta

# Edit refdata/derived/hpv16_tree/selected, then re-run without --init-selection:
scripts/hpv16_select_ncbi_genomes.sh \
  refdata/raw/hpv16_tree/HPV16-NCBIVirus.tsv \
  refdata/raw/hpv16_tree/HPV16-NCBIVirus.fasta \
  refdata/derived/hpv16_tree/selected \
  refdata/derived/hpv16_tree/selected.fasta \
  refdata/derived/hpv16_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 002). Set your sample IDs explicitly:

```bash
OUT_DIR=refdata/derived/hpv16_tree \
BCF_RUN_ID=$(cat config/hpv16_tree_bcf_run.txt) \
SAMPLES="<space-separated sample IDs>" \
scripts/hpv16_prepare_samples.sh
```

5) Run the tree pipeline:

```bash
analysis-input2/003.0.hpv16_tree/scripts/run.sh
```

#### HPV18 tree

1) Place these files under `refdata/raw/hpv18_tree/`:
   - `HPV18_lineages.tsv`
   - `HPV18-NCBIVirus.fasta`
   - `HPV18-NCBIVirus.tsv`

2) Place prepared inputs under `refdata/derived/hpv18_tree/`:
   - `outgroups.fasta`
   - `lineages_ref_renamed.fasta` (from the shared lineage prep above)

3) Create (then edit) the selection file, and generate `selected_renamed.fasta`:

```bash
scripts/hpv18_select_ncbi_genomes.sh --init-selection \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  refdata/derived/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  refdata/derived/hpv18_tree/selected.fasta \
  refdata/derived/hpv18_tree/selected_renamed.fasta

# Edit refdata/derived/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv, then re-run without --init-selection:
scripts/hpv18_select_ncbi_genomes.sh \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.tsv \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.fasta \
  refdata/raw/hpv18_tree/HPV18-NCBIVirus.acc_country.tsv \
  refdata/derived/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv \
  refdata/derived/hpv18_tree/selected.fasta \
  refdata/derived/hpv18_tree/selected_renamed.fasta
```

4) Build `samples.fasta` from mapping results (step 002). By default the script
derives samples from `analysis-input2/002.0.mapping_vs_pave/reports/strains.tsv`
by selecting rows with top strain `HPV18` for the run ID:

```bash
OUT_DIR=refdata/derived/hpv18_tree \
BCF_RUN_ID=$(cat config/hpv18_tree_bcf_run.txt) \
scripts/hpv18_prepare_samples.sh
```

5) Run the tree pipeline:

```bash
analysis-input2/004.0.hpv18_tree/scripts/run.sh
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
analysis-input1/002.0.bowtie_vs_pave/scripts/run_all.sh -resume
```
