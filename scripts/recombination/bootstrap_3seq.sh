#!/usr/bin/env bash
set -euo pipefail

install_root="$1"
requested_bin="${2:-}"
requested_table="${3:-}"
table_size="${4:-700}"
summary_json="${5:-3seq_bootstrap.json}"

mkdir -p "$install_root"

if [[ -n "$requested_bin" && -n "$requested_table" ]]; then
  if [[ ! -x "$requested_bin" ]]; then
    echo "Provided 3SEQ binary is not executable: $requested_bin" >&2
    exit 1
  fi
  if [[ ! -f "$requested_table" ]]; then
    echo "Provided 3SEQ p-value table not found: $requested_table" >&2
    exit 1
  fi
  python3 - <<'PY' "$requested_bin" "$requested_table" "$summary_json"
import json
import sys
payload = {
    "source": "user_supplied",
    "three_seq_bin": sys.argv[1],
    "three_seq_table": sys.argv[2],
}
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
  exit 0
fi

src_zip="$install_root/3seq_build_170612.zip"
src_dir="$install_root/3seq build 170612"
bin_path="$src_dir/3seq"
table_tgz="$install_root/pvaluetable.2017.700.tgz"
table_path="$install_root/pvaluetable.2017.700"

if [[ ! -f "$src_zip" ]]; then
  curl -LfsS "https://mol.ax/rxiv/3seq_build_170612.zip" -o "$src_zip"
fi

if [[ ! -d "$src_dir" ]]; then
  unzip -q "$src_zip" -d "$install_root"
fi

if [[ ! -x "$bin_path" ]]; then
  make -C "$src_dir"
fi

if [[ ! -f "$table_path" ]]; then
  if [[ ! -f "$table_tgz" ]]; then
    if ! curl -LfsS "https://www.dropbox.com/s/zac4wotgdmm3mvb/pvaluetable.2017.700.tgz?dl=1" -o "$table_tgz"; then
      "$bin_path" -g "$table_path" "$table_size"
    fi
  fi
  if [[ -f "$table_tgz" && ! -f "$table_path" ]]; then
    if ! tar -xzf "$table_tgz" -C "$install_root"; then
      rm -f "$table_tgz"
    fi
  fi
  if [[ ! -f "$table_path" ]]; then
    "$bin_path" -g "$table_path" "$table_size"
  fi
fi

if [[ ! -x "$bin_path" ]]; then
  echo "3SEQ bootstrap failed: compiled binary not found at $bin_path" >&2
  exit 1
fi

if [[ ! -f "$table_path" ]]; then
  echo "3SEQ bootstrap failed: p-value table not found at $table_path" >&2
  exit 1
fi

python3 - <<'PY' "$bin_path" "$table_path" "$summary_json"
import json
import sys
payload = {
    "source": "bootstrapped",
    "three_seq_bin": sys.argv[1],
    "three_seq_table": sys.argv[2],
}
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
