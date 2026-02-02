# OPERATIONS

Runbook with concrete commands and fixes (how to run + troubleshoot).

Rules:
- Put runnable commands and troubleshooting here.
- Do not turn this into a catalog (keep that in `.agents/SKILLS.md`) or an ordered workflow spec (keep that in `.agents/WORKFLOWS.md`).

## Conventions

- User-editable configuration is in `config/`; technical Nextflow config is in `pipelines/config/`. Sample lists live in `metadata/`.
- Raw reference inputs live in `refdata/raw/`; derived reference assets live in `refdata/derived/`.
- Outputs are written to each step's `output/` and `reports/`.
- When changing directory layout, update `CONTENTS.md` and `.agents/INVENTORY.md`.
- Avoid user-specific absolute paths in scripts; require tools via PATH or
  configurable env vars (e.g., `CONDA_EXE`).
- Default parallelism is capped at 24 concurrent tasks via `process.maxForks` and `executor.queueSize` in `pipelines/config/common.technical.config`.
- MultiQC reports are written under each step's `reports/` (phylo tree steps use `output/reports/`). Ensure the MultiQC process outputs files at the process root and publish to `reports/` to avoid duplicated `multiqc/multiqc_report.html` paths.
- MultiQC method summaries should cite the primary tool papers; update the relevant `config/*.multiqc.yml` when pipeline steps change.
- MultiQC custom sections should be configured under `custom_data` with explicit `plot_type` and any table inputs connected via `sp:` search patterns in the same config.

## Running pipelines

### analysis-input1 bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/centrifuge_bucketing.technical.config \
  -c config/centrifuge_bucketing.config \
  -c config/analysis-input1_001.centrifuge.config \
  -resume
```

MultiQC report is written to `analysis-input1/001.0.centrifuge/reports/multiqc_report.html`.

### Build the Centrifuge database (human + RefSeq archaea/bacteria/viral)

- Build the index and taxonomy under `refdata/centrifuge/`:
```
scripts/build_centrifuge_db.sh --outdir refdata/centrifuge --index-name human_abv --threads 24
```

- Point `config/centrifuge_bucketing.config` to the resulting paths, for example:
- `index = "refdata/centrifuge/human_abv"`
  - `taxdump = "refdata/centrifuge/taxonomy-YYYY-MM-DD"`

### analysis-input2 bucketing (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/centrifuge_bucketing_all.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/centrifuge_bucketing.technical.config \
  -c config/centrifuge_bucketing.config \
  -c config/analysis-input2_001.bucketing.config \
  -resume
```

### Bowtie vs PAVE mapping (Nextflow)

- analysis-input1:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/bowtie_vs_pave.technical.config \
  -c config/bowtie_vs_pave.config \
  -c config/analysis-input1_002.bowtie_vs_pave.config \
  -resume
```

- analysis-input2:

```
nextflow run pipelines/bowtie_vs_pave.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/bowtie_vs_pave.technical.config \
  -c config/bowtie_vs_pave.config \
  -c config/analysis-input2_002.mapping_vs_pave.config \
  -resume
```

### Cambodia SNP comparison (analysis-input2)

```
nextflow run pipelines/cambodia_snps.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/cambodia_snps.technical.config \
  -c config/cambodia_snps.config \
  -c config/analysis-input2_005.cambodia_snps.config \
  -resume
```

### VirStrain reports (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/virstrain.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/virstrain.technical.config \
  -c config/virstrain.config \
  -c config/analysis-input1_003.virstrain.config \
  -resume
```

### PAVE E6 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/pave_gene_mapping.technical.config \
  -c config/pave_gene_mapping.config \
  -c config/pave_e6.config \
  -resume
```

### PAVE E7 mapping (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/pave_gene_mapping.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/pave_gene_mapping.technical.config \
  -c config/pave_gene_mapping.config \
  -c config/pave_e7.config \
  -resume
```

### HPV16 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/phylo_tree.technical.config \
  -c config/phylo_tree.config \
  -c config/hpv16_tree.config \
  -resume
```

### HPV18 phylogenetic tree (Nextflow)

- Run with Nextflow:
```
nextflow run pipelines/phylo_tree.nf \
  -c pipelines/config/common.technical.config \
  -c pipelines/config/phylo_tree.technical.config \
  -c config/phylo_tree.config \
  -c config/hpv18_tree.config \
  -resume
```

### Generate PAVE feature tables (derived)

Coverage statistics use feature tables derived from the PAVE GFF3 files.
Generate them under `refdata/derived/pave/features_tsv` with:

```
scripts/gff3_to_features_tsv.run_all.sh \
  refdata/raw/pave/gff3 \
  refdata/derived/pave/features_tsv
```

## Reruns and resume

- Nextflow: use `-resume` to reuse successful tasks.
- Scripts: remove a step's `output/` to force a full rerun.

## Troubleshooting

- Check `.nextflow.log` for pipeline errors.
- Inspect process work directories under `work/` and read `.command.sh`, `.command.err`, `.command.out`.
- If tools are missing, confirm the Conda env file under `pipelines/conda_env/` is referenced by the matching `pipelines/config/*.technical.config`.
- Nextflow requires Java 17+; if Conda provides an older Java, use the env in `pipelines/conda_env/nextflow_java.env.yml`:
- When adding a new Nextflow parameter in a pipeline (e.g. `params.multiqc_config`), also add it to the matching `config/*.config` (user) or `pipelines/config/*.technical.config` (technical) file to avoid “undefined parameter” warnings.

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
for step in analysis-input1/* analysis-input2/*; do
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
