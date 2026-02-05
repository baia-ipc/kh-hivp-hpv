# Kh_HIVp_HPV

This repository contains a reproducible workflow used for HPV sequencing analysis.

Two analyses are included:

- `prelim_analysis`: analysis of the first three MiSeq runs (all patients + controls).
- `targeted_analysis`: deeper sequencing for HPV16/HPV18‑positive samples.

To run the analyses:

- place or link input reads under `input_reads/`
- place reference inputs under `refdata/`
- ensure Nextflow and Conda are installed
- run the wrapper scripts in `bin/`

A detailed user manual is available under `docs/USER_MANUAL.md`.

Each analysis consists of multiple steps (01, 02, …). Outputs and reports
are written under `outs/<analysis>/<step>/`.

Aggregated reports and some key results files are collected under
`results`.

The organization of the data and code in the repository is described in
`docs/CONTENTS.md`.

A technical manual for developers is available under
`docs/developers/DEVELOPER_MANUAL.md`.
