#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

"$SCRIPTSDIR/preliminary-analysis-all-patients.steps/001.0.centrifuge.run.sh" "${step1_args[@]}" "${common_args[@]}"
"$SCRIPTSDIR/preliminary-analysis-all-patients.steps/002.0.bowtie_vs_pave.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/preliminary-analysis-all-patients.steps/003.0.virstrain.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/preliminary-analysis-all-patients.steps/004.0.bowtie_vs_pave.E6.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/preliminary-analysis-all-patients.steps/005.0.bowtie_vs_pave.E7.run.sh" "${common_args[@]}"
