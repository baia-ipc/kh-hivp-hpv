# Method

This step is implemented as a Nextflow pipeline:

- Pipeline: `pipelines/bowtie_vs_pave.nf`
- Config: `config/bowtie_vs_pave.config`
- Bucket selection: `metadata/pave_bucket_tid.txt`

Wrappers:

- `run_all.sh` runs all samples in the bucketed output.
- `run.sh` runs a single sample pair.

The pipeline performs:

1) create bowtie2 index (if missing)
2) alignment using `bowtie2 --all` (allowing multiple matches)
3) counting alignments with `samtools idxstats`
4) rough strain assignment via `scripts/identify_top_strains.py`
5) coverage summary and variant calling
