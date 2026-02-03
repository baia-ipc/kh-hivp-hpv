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

"$SCRIPTSDIR/prelim_analysis.steps/001.0.centrifuge.run.sh" "${step1_args[@]}" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/002.0.bowtie_vs_pave.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/003.0.virstrain.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/004.0.bowtie_vs_pave.E6.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/005.0.bowtie_vs_pave.E7.run.sh" "${common_args[@]}"
