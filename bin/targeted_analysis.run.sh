#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/.." && pwd )"

if [ -z "${NXF_HOME:-}" ]; then
  export NXF_HOME="${PRJROOT}/.nextflow"
fi

step1_args=()
common_args=()

for arg in "$@"; do
  case "$arg" in
    --skip-align|--skip_align|--skip-align=*|--skip_align=*)
      step1_args+=("$arg")
      ;;
    *)
      common_args+=("$arg")
      ;;
  esac
done

"$SCRIPTSDIR/targeted_analysis.steps/01.bucketing.run.sh" "${step1_args[@]}" "${common_args[@]}"
"$SCRIPTSDIR/targeted_analysis.steps/02.mapping_vs_pave.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/targeted_analysis.steps/03.variant_analysis.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/targeted_analysis.steps/04.hpv16_tree.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/targeted_analysis.steps/05.hpv18_tree.run.sh" "${common_args[@]}"
