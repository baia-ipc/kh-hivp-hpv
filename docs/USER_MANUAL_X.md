# User Manual

## Prerequisites

The following software should be installed and available in `PATH`:

- Nextflow (and Java 17+, required by Nextflow)
- Conda (used by Nextflow for environment management)

## Input reads

### Copy or link input reads

The sequencing reads are not included in the repository, due
to their large size.

Copy or link each sequencing run folder under `input_reads/prelim_analysis` and
`input_reads/targeted_analysis`. Two layouts are supported, which are used,
respectively in prelim and targeted analyses:

1. `*_analysis/RUN_ID/Fastq/SAMPLE_R1.fastq.gz` (Reads in a Fastq layout)
2. `*_analysis/RUN_ID/SAMPLE_R1.fastq.gz` (no Fastq subdirectory)

### Sample sheets

The sequencings samples are described in sample sheets under `metadata/` (see below).
For replicating the analyses of the manuscript, no editing is necessary,
as long as the expected directory structure of the input reads is maintained (see above).
For more information about the sample sheets, see below.

## Reference data

## Configuration

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

## 5) Prepare reference data (`refdata/`)

### 5.1 PAVE reference (raw)

Place the PAVE reference FASTA (and gene FASTAs if used) under `refdata/pave/`.
If you use variant effect annotation, place the PAVE GFF3 files under
`refdata/pave/gff3/` (one GFF3 per reference sequence).

BED files used for E6/E7 SNP extraction are derived from the GFF3 inputs and
stored under `derived_data/refdata/pave/bed/` (see below).

These paths are wired via the technical pipeline configs (under `config/pipelines/`).

### 5.2 PAVE feature tables (derived)

Coverage statistics use tabular feature files (TSV) derived from the PAVE GFF3s.
Generate them with:

```
scripts/pave/gff3_to_features_tsv.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/features_tsv
```

These TSVs are consumed by the Bowtie vs PAVE steps (coverage summaries).
If the directory is missing or empty, the pipeline will generate it automatically.

### 5.2b PAVE BED files (derived)

E6/E7 SNP extraction uses BED intervals derived from the same GFF3 inputs.
Generate them with:

```
scripts/pave/gff3_to_bed.run_all.sh \
  refdata/pave/gff3 \
  derived_data/refdata/pave/bed
```

These BED files are required by the Bowtie vs PAVE steps and the variant analysis
database comparison.
If the directory is missing or empty, the pipelines will generate it automatically.

### 6.3 Phylogenetic tree inputs (raw + derived)

Place raw inputs under:

- `refdata/hpv16_tree`
- `refdata/hpv18_tree`

Derived tree inputs live under:

- `derived_data/refdata/hpv16_tree`
- `derived_data/refdata/hpv18_tree`

All derived inputs are generated automatically by the tree pipeline if missing
or out of date. The only manual steps are preparing the raw reference files
under `refdata/` (downloads + curated selection lists).

#### Required raw inputs (HPV16)

Place these files under `refdata/hpv16_tree/`:
- `HPV16_lineages.tsv`
- `HPV16-NCBIVirus.fasta`
- `HPV16-NCBIVirus.tsv`

Outgroup accessions are provided in:
- `metadata/hpv16_tree/hpv16_tree_outgroups.txt`
If you want different outgroups, edit the list and ensure those accessions are
present in the PAVE FASTA (`refdata/pave/pave_hsa.fas`).

Lineage reference tips for optional lineage assignment live in:
- `metadata/hpv16_tree/hpv16_lineage_refs.tsv`
If you update the lineages table, regenerate the references accordingly.

How to obtain the HPV16 inputs:

- PAVE lineages table:
  - Visit the PAVE variant genomes page.
  - Search for HPV16.
  - Copy the lineage table and save it as `refdata/hpv16_tree/HPV16_lineages.tsv`.
- NCBI Virus downloads (complete genomes):
  - Search NCBI Virus for “Human papillomavirus 16”.
  - Filter to “Sequence Quality: Nucleotide Completeness: complete”.
  - Download sequence data as FASTA (Nucleotide) using a custom definition line:
    - `Accession Country Length Species GenBank/RefSeq GenBank Title Collection Date`
  - Save as `refdata/hpv16_tree/HPV16-NCBIVirus.fasta`.
  - Download the results table as TSV with columns:
    - `Accession`, `GenBank_RefSeq`, `Organism_Name`, `Species`, `Genotype`,
      `Isolate`, `GenBank_Title`, `Length`, `Nuc_Completeness`, `Geo_Location`,
      `Country`, `Host`, `Tissue_Specimen_Source`, `Submitters`, `Publications`,
      `Collection_Date`, `Release_Date`, `Molecule_type`
  - Save as `refdata/hpv16_tree/HPV16-NCBIVirus.tsv`.
- Selection list:
  - List the accessions to include (one per line) in:
    - `metadata/hpv16_tree/hpv16_tree_db_selection.txt`
  - The pipeline derives `derived_data/refdata/hpv16_tree/HPV16-NCBIVirus.selected.tsv`
    from the NCBI TSV plus this accession list.

#### Required raw inputs (HPV18)

Place these files under `refdata/hpv18_tree/`:
- `HPV18_lineages.tsv`
- `HPV18-NCBIVirus.fasta`
- `HPV18-NCBIVirus.tsv`

Outgroup accessions are provided in:
- `metadata/hpv18_tree/hpv18_tree_outgroups.txt`
If you want different outgroups, edit the list and ensure those accessions are
present in the PAVE FASTA (`refdata/pave/pave_hsa.fas`).

Lineage reference tips for optional lineage assignment live in:
- `metadata/hpv18_tree/hpv18_lineage_refs.tsv`
If you update the lineages table, regenerate the references accordingly.

How to obtain the HPV18 inputs:

- PAVE lineages table:
  - Visit the PAVE variant genomes page.
  - Search for HPV18.
  - Copy the lineage table and save it as `refdata/hpv18_tree/HPV18_lineages.tsv`.
- NCBI Virus downloads (complete genomes):
  - Search NCBI Virus for “Human papillomavirus 18”.
  - Filter to “Sequence Quality: Nucleotide Completeness: complete”.
  - Download sequence data as FASTA (Nucleotide) using a custom definition line:
    - `Accession Country Length Species GenBank/RefSeq GenBank Title Collection Date`
  - Save as `refdata/hpv18_tree/HPV18-NCBIVirus.fasta`.
  - Download the results table as TSV with columns:
    - `Accession`, `GenBank_RefSeq`, `Organism_Name`, `Species`, `Genotype`,
      `Isolate`, `GenBank_Title`, `Length`, `Nuc_Completeness`, `Geo_Location`,
      `Country`, `Host`, `Tissue_Specimen_Source`, `Submitters`, `Publications`,
      `Collection_Date`, `Release_Date`, `Molecule_type`
  - Save as `refdata/hpv18_tree/HPV18-NCBIVirus.tsv`.
- Selection list:
  - List the accessions to include (one per line) in:
    - `metadata/hpv18_tree/hpv18_tree_db_selection.txt`
  - The pipeline derives `derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv`
    from the NCBI TSV plus this accession list.

#### Running the tree pipelines

```
bin/targeted_analysis.steps/04.hpv16_tree.run.sh
bin/targeted_analysis.steps/05.hpv18_tree.run.sh
```

If the targeted mapping step contains multiple run IDs, set `bcf_run_id` in the
`targeted_hpv16_tree` / `targeted_hpv18_tree` profiles inside
`config/analyses/targeted_analysis.config` so sample consensus can be built.

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

`results/reports/prelim_analysis/01_bucketing.report.html`

VirStrain (step 04) is optional and does not run unless you pass
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
  outs/prelim_analysis/02.mapping_vs_pave/RUN_ID/SAMPLE
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

## More information

### Sample sheets

The sample sheets for the preliminary and targeted analysis are provided in the
repository and should be edited, only if the `input_reads` organization is not
matched (directory names):
- `metadata/seq_samples/samples_prelim_analysis.tsv`
- `metadata/seq_samples/samples_targeted_analysis.tsv`

Each row contains:
- `run ID`
- `sample_id`, i.e. the normalized identifier used in outputs (e.g., `KHCA-064`,
`HPV-019`)
- FASTQ directory (relative to the repo root),
- `fastq_sample_id`, i.e. the original naming found in the FASTQ
files (e.g., `KHCA064`, `HPV019`, `HVP-110`) so the pipelines can locate reads
even when the raw file prefix differs from the normalized ID
