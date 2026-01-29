# Method

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/pave_gene_mapping.nf`
- Config: `config/pave_e7.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `run_all.sh` runs all samples in the bucketed output.
- `run.sh` runs a single sample pair.

Outputs:

- Per-sample mapping and depth statistics under `output/<RUNID>/`.
- Aggregated reports under `reports/`:
  - `strains.tsv`
  - `depth_stats.unfiltered.tsv`
  - `depth_stats.filtered.tsv`
- MultiQC report under `reports/multiqc_report.html`.
