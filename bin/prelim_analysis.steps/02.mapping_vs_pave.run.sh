#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"

exec python3 "$PRJROOT/bin/run_step.py" \
  "$PRJROOT/config/steps/prelim_analysis.02.mapping_vs_pave.json" \
  "$@"
