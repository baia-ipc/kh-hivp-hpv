# OPERATIONS

Runbook with concrete commands and fixes (how to run + troubleshoot).

Rules:
- Put runnable commands and troubleshooting here.
- Do not turn this into a catalog (keep that in `.agents/SKILLS.md`) or an ordered workflow spec (keep that in `.agents/WORKFLOWS.md`).

## Conventions

- User-editable configuration is in `config/`; step path configs are under `bin/config/`; technical Nextflow config is in `config/pipelines/`. Sample lists live in `metadata/`.
- Raw reference inputs live in `refdata/`; derived reference assets live in `intermediate_files/refdata/`.
- Outputs are written to each step's `output/` and `reports/`.
- When changing directory layout, update `CONTENTS.md` and `.agents/INVENTORY.md`.
- Avoid user-specific absolute paths in scripts; require tools via PATH or
  configurable env vars (e.g., `CONDA_EXE`).
- Default parallelism is tied to `params.threads` (from `config/user.config`) via `process.maxForks` and `executor.queueSize` in `config/pipelines/common.config`.
- MultiQC reports are written under each step's `reports/` (phylo tree steps use `output/reports/`). Ensure the MultiQC process outputs files at the process root and publish to `reports/` to avoid duplicated `multiqc/multiqc_report.html` paths.
- MultiQC method summaries should cite the primary tool papers; update the relevant `pipelines/multiqc/*.multiqc.yml` when pipeline steps change.
- MultiQC custom sections should be configured under `custom_data` with explicit `plot_type` and any table inputs connected via `sp:` search patterns in the same config.

## Running pipelines

### Wrapper scripts (bin/)

Run whole analyses:

```
bin/preliminary-analysis-all-patients.run.sh
bin/targeted-analysis-hpv16-hpv18.run.sh
```

Run individual steps (all samples):

```
bin/preliminary-analysis-all-patients.steps/001.0.centrifuge.run.sh
bin/targeted-analysis-hpv16-hpv18.steps/002.0.mapping_vs_pave.run.sh
```

Run a single sample (for steps that support it):

```
bin/targeted-analysis-hpv16-hpv18.steps/single_sample/002.0.mapping_vs_pave.run_sample.sh
```

### preliminary-analysis-all-patients bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/centrifuge_bucketing.config \
  -c config/user.config \
  -c bin/config/preliminary-analysis-all-patients.config \
  -profile preliminary_centrifuge \
  -resume
```

MultiQC report is written to `preliminary-analysis-all-patients/001.0.centrifuge/reports/multiqc_report.html`.

### Build the Centrifuge database (human + RefSeq archaea/bacteria/viral)

- Build the index and taxonomy under `refdata/centrifuge/`:
```
scripts/centrifuge_bucketing/build_centrifuge_db.sh --outdir refdata/centrifuge --index-name human_abv --threads 24
```

- Point `config/user.config` to the resulting paths, for example:
- `index = "refdata/centrifuge/human_abv"`
  - `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

### targeted-analysis-hpv16-hpv18 bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/centrifuge_bucketing.config \
  -c config/user.config \
  -c bin/config/targeted-analysis-hpv16-hpv18.config \
  -profile targeted_bucketing \
  -resume
```

### Bowtie vs PAVE mapping (Nextflow)

- preliminary-analysis-all-patients:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/bowtie_vs_pave.config \
  -c config/user.config \
  -c bin/config/preliminary-analysis-all-patients.config \
  -profile preliminary_bowtie_vs_pave \
  -resume
```

- targeted-analysis-hpv16-hpv18:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/bowtie_vs_pave.config \
  -c config/user.config \
  -c bin/config/targeted-analysis-hpv16-hpv18.config \
  -profile targeted_mapping_vs_pave \
  -resume
```

### SNPs samples vs database (targeted-analysis-hpv16-hpv18)

```
nextflow run pipelines/database_snps.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/database_snps.config \
  -c config/user.config \
  -c bin/config/targeted-analysis-hpv16-hpv18.config \
  -profile targeted_snps_samples_vs_db \
  -resume
```

### VirStrain reports (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/virstrain.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/virstrain.config \
  -c config/user.config \
  -c bin/config/preliminary-analysis-all-patients.config \
  -profile preliminary_virstrain \
  -resume
```

### PAVE E6 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/pave_gene_mapping.config \
  -c config/user.config \
  -c bin/config/preliminary-analysis-all-patients.config \
  -profile preliminary_pave_e6 \
  -resume
```

### PAVE E7 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/pave_gene_mapping.config \
  -c config/user.config \
  -c bin/config/preliminary-analysis-all-patients.config \
  -profile preliminary_pave_e7 \
  -resume
```

### HPV16 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/phylo_tree.config \
  -c config/pipelines/phylo_tree.hpv16.config \
  -c config/user.config \
  -c bin/config/targeted-analysis-hpv16-hpv18.config \
  -profile targeted_hpv16_tree \
  -resume
```

### HPV18 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c config/pipelines/common.config \
  -c config/pipelines/phylo_tree.config \
  -c config/pipelines/phylo_tree.hpv18.config \
  -c config/user.config \
  -c bin/config/targeted-analysis-hpv16-hpv18.config \
  -profile targeted_hpv18_tree \
  -resume
```

### Generate PAVE feature tables (derived)

Coverage statistics use feature tables derived from the PAVE GFF3 files.
Generate them under `intermediate_files/refdata/pave/features_tsv` with:

```
scripts/pave_reference/gff3_to_features_tsv.run_all.sh \
  refdata/pave/gff3 \
  intermediate_files/refdata/pave/features_tsv
```

### Generate PAVE BED files (derived)

E6/E7 SNP extraction relies on BED intervals derived from the same PAVE GFF3s.
Generate them under `intermediate_files/refdata/pave/bed` with:

```
scripts/pave_reference/gff3_to_bed.run_all.sh \
  refdata/pave/gff3 \
  intermediate_files/refdata/pave/bed
```

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `output/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file under `pipelines/conda_env/` is referenced by the matching `config/pipelines/*.config`.
- Nextflow requires Java 17+; if Conda provides an older Java, use the env in `pipelines/conda_env/nextflow_java.env.yml`:
- When adding a new Nextflow parameter in a pipeline (e.g. `params.multiqc_config`), also add it to `config/user.config` (user) or the matching `config/pipelines/*.config` (technical) file to avoid “undefined parameter” warnings.

```
conda env create -f pipelines/conda_env/nextflow_java.env.yml
conda activate nextflow-java
```

If you do not want to activate any env, run with explicit Java (and optionally disable conda's CUDA probing if `conda info --json` fails):

```
CONDA_OVERRIDE_CUDA=0 \
JAVA_CMD=/usr/lib/jvm/java-21-openjdk-amd64/bin/java \
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
nextflow run <pipeline> -c <config> -resume
```

## Reference snapshots

To refresh the reference snapshot used for regression checks:

```
mkdir -p reference-results
for step in preliminary-analysis-all-patients/* targeted-analysis-hpv16-hpv18/*; do
  [ -d "$step" ] || continue
  for sub in output reports index; do
    src="$step/$sub"
    if [ -d "$src" ]; then
      dest="reference-results/$step/$sub"
      mkdir -p "$dest"
      cp -a "$src/." "$dest/"
    fi
  done
done
```

## Updating inputs

- Update sample lists in `metadata/`.
- Ensure reference indices exist in step `index/` or a shared `refdata/` location.
