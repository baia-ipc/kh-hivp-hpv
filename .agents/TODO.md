# TODO

- [ ] Convert manual commands into scripts under `scripts/` or `pipelines/` as appropriate.
- [ ] Move any scripts living in output directories into `scripts/` or `pipelines/` and wire them in via parameters.
- [ ] Minimize step-specific scripts so they delegate to shared logic in `scripts/` or `pipelines/`.
- [x] Define conventional `refdata/raw` and `refdata/derived` locations for user-provided inputs and derived assets.
- [ ] Create a shared index directory under the repo root for reusable indices (e.g., pave).
- [x] Replace `analysis-1/` and `analysis-2/` with `preliminary-analysis-all-patients/` and `targeted-analysis-hpv16-hpv18/`.
- [x] Move HPV16/HPV18 tree steps into `targeted-analysis-hpv16-hpv18/`.
- [x] Update `CONTENTS.md` after any directory reordering.
