#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/../.." && pwd )"

exec python3 "$PRJROOT/bin/run_step.py" \
  "$PRJROOT/config/steps/targeted_analysis.01.bucketing.json" \
  "$@"
