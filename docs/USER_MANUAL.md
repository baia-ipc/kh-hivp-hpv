# User Manual

## Prerequisites

The following software should be installed and available in `PATH`:

- Nextflow (and Java 17+, required by Nextflow)
- Conda (used by Nextflow for environment management)

## Input and reference data

### Input reads

The sequencing reads are not included in the repository, due to their large
size.

Download the sequencing reads from SRA and copy or link them in folders under
`input_reads/prelim_analysis` or `input_reads/targeted_analysis`.

Reads files (`*.fastq.gz`) can be directly under the `RUN_ID` folder or in a
`Fastq/` subfolder, as long as the sample sheets (see below) point to the
correct location.


However, for replicating the analyses of the manuscript, no editing to configuration
files is needed if the following structure and file/directory names are used.

For the preliminary analysis:
```
input_reads/prelim_analysis: directory containing 3 folders:
  HPV_150123_run01
  HPV_250523_run02
  HPV_160823_run03
```

each of these three folders contains the FASTQ files in a `Fastq/` subfolder, e.g.:
```
  HPV_150123_run01:
    Fastq:
      *.fastq.gz
```

For the targeted analysis:
```
input_reads/targeted_analysis: directory containing the fastq files directly
```

## Reference data

### PAVE

The reference sequences (Fasta) and annotations (gff3) for all human HPV
can be downloaded from PAVE using the web interface.

- Open the PAVE website: https://pave.niaid.nih.gov/
- Click on "Search" and select "Search Databases"
- From the left pane, select "Database: Genomes" and
  "Select Filters: Host Species: Homo sapiens"
- Click on "Select All", then click on "Download" and select "Download Fasta";
  this donwloads a Fasta file which must renamed to `pave_hsa.fas` and placed
  under `refdata/pave`
- Click on "Download" again and select "Download gff3";
  this downloads a zip file, containing one GFF3 file for each HPV strain,
  which must be unzipped before placing its contents under `refdata/pave/gff/`
- On the left pane, click on "Database: Genes and regions" and
  "Select Filters: Host Species: Homo sapiens", as well as
  "PV Genes and Regions: E6"
- Click on "Select All", then click on "Download" and select "Download Fasta";
  this donwloads a Fasta file which must renamed to `pave_hsa.E6.fas` and
  placed under `refdata/pave`
- On the left pane, change the "PV Genes and Regions" filter to "E7"
- Click on "Select All", then click on "Download" and select "Download Fasta";
  this donwloads a Fasta file which must renamed to `pave_hsa.E7.fas` and
  placed under `refdata/pave`

Other filenames are allowed instead of the ones specified above,
but it would require editing the configuration files.

## Centrifuge database

The repository expects a prebuilt HPVC Centrifuge index plus an NCBI taxonomy
dump to be available externally. The default configuration points to:

- index: `/srv/databases/centrifuge/hpvc/latest/hpvc`
- taxdump: `/srv/databases/centrifuge/hpvc/latest/taxonomy-2023-10-30`

The HPVC index itself is distributed as a prebuilt download. The retrieval
recipe is documented in `/srv/databases/centrifuge/hpvc/README.md`. If another
installation path is used, update the user configuration accordingly.

### HPV16 and HPV18 lineage reference sequences

The lineage reference sequences for HPV16 and HPV18 must be downloaded from
PAVE and can be obtained as followed:
- Visit the PAVE variant genomes page.
- Search for HPV16 or HPV18.
- Copy the lineage table and save it as
  `refdata/hpv16_tree/HPV16_lineages.tsv` or, respectively,
  `refdata/hpv18_tree/HPV18_lineages.tsv`.

### HPV16 and HPV18 NCBI Virus data

How to obtain the HPV16 and HPV18 data from NCBI virus:

- NCBI Virus downloads (complete genomes):
  - Search NCBI Virus for “Human papillomavirus 16”. (or 18)
  - Filter to “Sequence Quality: Nucleotide Completeness: complete”.
  - Download sequence data as FASTA (Nucleotide) using a custom definition line:
    - `Accession Country Length Species GenBank/RefSeq GenBank Title Collection Date`
  - Save as `refdata/hpv16_tree/HPV16-NCBIVirus.fasta`
    or `refdata/hpv18_tree/HPV18-NCBIVirus.tsv`.
  - Download the results table as TSV with columns:
    - `Accession`, `GenBank_RefSeq`, `Organism_Name`, `Species`, `Genotype`,
      `Isolate`, `GenBank_Title`, `Length`, `Nuc_Completeness`, `Geo_Location`,
      `Country`, `Host`, `Tissue_Specimen_Source`, `Submitters`, `Publications`,
      `Collection_Date`, `Release_Date`, `Molecule_type`
  - Save as `refdata/hpv16_tree/HPV16-NCBIVirus.tsv`.

### HPV16 and HPV18 selections for the phylogenetic tree

- Selection list:
  - List the accessions to include (one per line) in:
    - `metadata/hpv16_tree_db_selection.txt`
    - `metadata/hpv18_tree_db_selection.txt`

### HPV16 and HPV18 outgroup accessions

Outgroup accessions are provided in:
- `metadata/hpv16_tree_outgroups.txt`
If you want different outgroups, edit the list and ensure those accessions are
present in the PAVE FASTA (`refdata/pave/pave_hsa.fas`).

### Recombination analysis metadata inputs

The recombination workflow runs as a screening step followed by one step per
detection method:

- step 06: `recombination_screen`
- step 07: `recombination_3seq`
- step 07: `recombination_geneconv`

Two further steps are available but are not part of the standard run:
`recombination_openrdp` (step 07), which adds the RDP, Bootscan, SiScan and
Chimaera scans, and `recombination_confirmation` (step 08), which checks
OpenRDP candidates against breakpoint-window trees and mapped reads. The
confirmation step needs the GARD breakpoints, so enable GARD in step 06
(`recombination_enable_gard = true`) before running them.

Step 06 uses metadata-driven sample FASTA input (`metadata_fasta` mode), then
automatically augments each HPV type with same-type tree-selected background
references.

Fill this table with one row per sample consensus FASTA:

- `metadata/recombination_analysis/sequence_sets/targeted_analysis.recombination_sequences.tsv`
  - required columns: `run_id`, `sample_id`, `hpv_type`, `fasta_path`

Optional metadata:

- `metadata/recombination_analysis/exclude_lists/default_controls.txt`
  - explicit sample IDs to exclude
- `metadata/recombination_analysis/hpv_type_groups/high_risk_hpv_types.txt`
  - optional HPV type groups to help curate allowlists

By default, summaries also exclude technical artifacts matching:
`H2O`, `HPV-110`, `Ex`, `HPV-19`, and `Undetermined*`.

The automated recombination workflow then:

- splits HPV16 and HPV18 into separate analyses
- adds same-type background references from the tree step outputs
- aligns each type-specific set with MAFFT in step 06
- scans each alignment for recombinant triplets with 3SEQ in step 07
- scans each alignment for converted fragments with GENECONV in step 07

Step 06 prepares and aligns the input only; it makes no recombinant call. Each
step-07 method reports its own candidates, and a sample is reported as a
candidate only when its corrected p-value passes the threshold for that method
(0.05 by default).

## User configuration file

The user pipeline configuration file is `config/user.config`.
The only values which the user might want to change are the number of threads
to use, phylogenetic tree parameters, and recombination parameters (MAFFT
settings, method p-value thresholds, and filtering behavior).

## Run the analyses

After the preparation steps above, run the analyses using the wrapper scripts below.

### Preliminary analysis

All steps in one go:

```
bin/prelim_analysis.run.sh
```

VirStrain is optional and does not run unless you pass
`--run-virstrain` to the wrapper.

Or run each step individually:

```
bin/prelim_analysis.steps/01.bucketing.run.sh
bin/prelim_analysis.steps/02.mapping_vs_pave.run.sh
bin/prelim_analysis.steps/03.variant_analysis.run.sh
bin/prelim_analysis.steps/04.virstrain.run.sh
```

### Targeted analysis

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
bin/targeted_analysis.steps/06.recombination_screen.run.sh
bin/targeted_analysis.steps/07.recombination_3seq.run.sh
bin/targeted_analysis.steps/07.recombination_geneconv.run.sh
```

The optional recombination steps are run the same way:

```
bin/targeted_analysis.steps/07.recombination_openrdp.run.sh
bin/targeted_analysis.steps/08.recombination_confirmation.run.sh
```

### Tree figure for publication

After steps 04 and 05, the combined HPV16 (A) and HPV18 (B) tree figure can be
drawn as PDF and 600 dpi TIFF:

```
bin/targeted_analysis.figures/phylo_tree_figure.run.sh
```

The files are written to `results/figures/targeted_analysis/`. The script needs
Python with matplotlib, biopython and pillow (for example the environment in
`pipelines/conda_env/recombination.env.yml`); set `PYTHON` to choose the
interpreter. Ultrafast bootstrap values from 70 are shown; values of 95 or more
are printed in bold black and lower ones in grey. Use `--min-support` and
`--strong-support` to change the two limits.

## Troubleshooting

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
- `metadata/samples_prelim_analysis.tsv`
- `metadata/samples_targeted_analysis.tsv`

Each row contains:
- `run ID`
- `sample_id`, i.e. the normalized identifier used in outputs (e.g., `KHCA-064`,
`HPV-019`)
- FASTQ directory (relative to the repo root),
- `fastq_sample_id`, i.e. the original naming found in the FASTQ
files (e.g., `KHCA064`, `HPV019`, `HVP-110`) so the pipelines can locate reads
even when the raw file prefix differs from the normalized ID

### Configuration files

Configuration files are located under `config/`.
These files point to data paths and set resource limits.

- Base pipeline config:
  - `config/user.config`: all user-editable pipeline parameters
- Step‑specific path configs (inputs/outputs) are stored under `config/analyses/` and are not typically edited by users:
  - `config/analyses/prelim_analysis.config`
  - `config/analyses/targeted_analysis.config`

### Run a single sample

Some steps provide a `run_sample.sh` wrapper under `bin/*steps/single_sample/` for
running one sample pair. The third argument is an output prefix used to infer
`run_id` and `sample_id`; outputs still go to the step output directory configured
in `config/`.

```
bin/prelim_analysis.steps/single_sample/02.mapping_vs_pave.run_sample.sh \
  /path/to/SAMPLE_R1.fastq.gz /path/to/SAMPLE_R2.fastq.gz \
  outs/prelim_analysis/02.mapping_vs_pave/RUN_ID/SAMPLE
```
