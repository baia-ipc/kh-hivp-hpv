# Method

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/virstrain.nf`
- Config: `config/virstrain.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `run_all.sh` runs all samples in the bucketed output.
- `run.sh` runs a single sample pair.

Outputs:

- Aggregated results table under `reports/strains.tsv`.
- Per-sample results under `output/<RUNID>/<SAMPLE>/`:
  - `VirStrain_report.txt` (assignments)
  - `VirStrain_report.html` (alignment graph)
- MultiQC report under `reports/multiqc/multiqc_report.html`.
