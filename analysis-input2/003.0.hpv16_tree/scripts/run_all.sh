#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$SCRIPTSDIR/run.sh" "$@"
