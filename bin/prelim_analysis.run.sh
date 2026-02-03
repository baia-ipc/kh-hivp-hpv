#!/usr/bin/env bash
set -euo pipefail

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJROOT="$( cd "$SCRIPTSDIR/.." && pwd )"

if [ -z "${NXF_HOME:-}" ]; then
  export NXF_HOME="${PRJROOT}/.nextflow"
fi

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

"$SCRIPTSDIR/prelim_analysis.steps/01.centrifuge.run.sh" "${step1_args[@]}" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/02.bowtie_vs_pave.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/03.bowtie_vs_pave.E6.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/prelim_analysis.steps/04.bowtie_vs_pave.E7.run.sh" "${common_args[@]}"
if [ "$run_virstrain" = true ]; then
  "$SCRIPTSDIR/prelim_analysis.steps/05.virstrain.run.sh" "${virstrain_args[@]}" "${common_args[@]}"
fi
