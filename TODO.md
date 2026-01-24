# TODO

- [ ] Convert manual commands into scripts under `scripts/` or `pipelines/` as appropriate.
- [ ] Move any scripts living in output directories into `scripts/` or `pipelines/` and wire them in via parameters.
- [ ] Minimize step-specific scripts so they delegate to shared logic in `scripts/` or `pipelines/`.
- [ ] Define a conventional `refdata/` location for user-provided inputs (e.g., selected strains for trees).
- [ ] Create a shared index directory under the repo root for reusable indices (e.g., pave).
- [ ] Replace `analysis-1/`, `analysis-2/`, `analysis-3/` with `analysis-input-1/` and `analysis-input-2/`.
- [ ] Move `analysis-3/steps/003.0.hpv16_tree/` and `analysis-3/steps/004.0.hpv18_tree/` into `analysis-input-2/`.
- [ ] Update `CONTENTS.md` after any directory reordering.
