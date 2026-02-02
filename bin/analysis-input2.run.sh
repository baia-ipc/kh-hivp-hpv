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

"$SCRIPTSDIR/001.0.bucketing.run.sh" "${step1_args[@]}" "${common_args[@]}"
"$SCRIPTSDIR/002.0.mapping_vs_pave.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/003.0.hpv16_tree.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/004.0.hpv18_tree.run.sh" "${common_args[@]}"
"$SCRIPTSDIR/005.0.cambodia_snps.run.sh" "${common_args[@]}"
