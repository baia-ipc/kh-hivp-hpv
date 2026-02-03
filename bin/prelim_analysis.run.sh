#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

step1_args=()
common_args=()
virstrain_args=()
run_virstrain=false

for arg in "$@"; do
  case "$arg" in
    --run-virstrain|--run_virstrain)
      run_virstrain=true
      virstrain_args+=("$arg")
      ;;
    --run-virstrain=*|--run_virstrain=*)
      value="${arg#*=}"
      if [ "$value" = "true" ] || [ "$value" = "1" ]; then
        run_virstrain=true
      fi
      virstrain_args+=("$arg")
      ;;
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
"$SCRIPTSDIR/prelim_analysis.steps/003.0.bowtie_vs_pave.E6.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/004.0.bowtie_vs_pave.E7.run.sh" "${common_args[@]}"
if [ "$run_virstrain" = true ]; then
  "$SCRIPTSDIR/prelim_analysis.steps/005.0.virstrain.run.sh" "${virstrain_args[@]}" "${common_args[@]}"
fi
