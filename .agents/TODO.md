# TODO

- [ ] Convert manual commands into scripts under `scripts/` or `pipelines/` as appropriate.
- [ ] Move any scripts living in output directories into `scripts/` or `pipelines/` and wire them in via parameters.
- [ ] Minimize step-specific scripts so they delegate to shared logic in `scripts/` or `pipelines/`.
- [x] Define conventional `refdata/` (raw inputs) and `intermediate_files/refdata/` (derived assets) locations.
- [x] Create a shared index directory under the repo root for reusable indices (e.g., pave).
- [x] Replace `analysis-1/` and `analysis-2/` with `prelim_analysis/` and `targeted_analysis/`.
- [x] Move HPV16/HPV18 tree steps into `targeted_analysis/`.
- [x] Update `CONTENTS.md` after any directory reordering.
