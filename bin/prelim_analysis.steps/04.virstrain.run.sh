#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"

exec python3 "$PRJROOT/scripts/steps/run_step.py" \
  "$PRJROOT/config/steps/prelim_analysis.04.virstrain.json" \
  "$@"
