#!/usr/bin/env bash
set -euo pipefail

# Build consensus sequences for samples to be included in tree inputs.

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

PAVE_FASTA=${PAVE_FASTA:-}
REF_FASTA=${REF_FASTA:-}
REF_NAME=${REF_NAME:-}
REF_PATTERN=${REF_PATTERN:-}
HPV_TYPE=${HPV_TYPE:-}
STRAINS_MATCH=${STRAINS_MATCH:-}
BCF_DIR=${BCF_DIR:-}
BCF_RUN_ID=${BCF_RUN_ID:-}
OUT_DIR=${OUT_DIR:-}
SAMPLES=${SAMPLES:-}
SAMPLES_FILE=${SAMPLES_FILE:-}
SAMPLES_TSV=${SAMPLES_TSV:-$REPO_ROOT/metadata/seq_samples/samples_targeted_analysis.tsv}
STRAINS_TSV=${STRAINS_TSV:-$REPO_ROOT/outs/targeted_analysis/02.mapping_vs_pave/reports/strains.tsv}
MAPPING_OUTDIR=${MAPPING_OUTDIR:-$REPO_ROOT/outs/targeted_analysis/02.mapping_vs_pave}
COV_STATS_TSV=${COV_STATS_TSV:-$MAPPING_OUTDIR/reports/cov_stats.tsv}
MIN_COV_BREADTH=${MIN_COV_BREADTH:-0.9}
MIN_CONSENSUS_DEPTH=${MIN_CONSENSUS_DEPTH:-10}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOFHELP'
Usage: prepare_samples.sh

Environment overrides:
  HPV_TYPE, REF_NAME, REF_PATTERN
  PAVE_FASTA, REF_FASTA
  BCF_DIR, BCF_RUN_ID, OUT_DIR
  SAMPLES, SAMPLES_FILE, SAMPLES_TSV
  STRAINS_TSV, STRAINS_MATCH, MAPPING_OUTDIR
  COV_STATS_TSV, MIN_COV_BREADTH, MIN_CONSENSUS_DEPTH
EOFHELP
  exit 0
fi

if [[ -z "$OUT_DIR" ]]; then
  echo "Error: OUT_DIR is required." >&2
  exit 1
fi

if [[ -z "$HPV_TYPE" ]]; then
  echo "Error: HPV_TYPE is required (e.g., HPV16 or HPV18)." >&2
  exit 1
fi

if [[ -z "$REF_NAME" ]]; then
  REF_NAME="${HPV_TYPE}REF"
fi

if [[ -z "$REF_PATTERN" ]]; then
  REF_PATTERN="${REF_NAME}.*"
fi

if [[ -z "$PAVE_FASTA" ]]; then
  PAVE_FASTA="$REPO_ROOT/refdata/pave/pave_hsa.fas"
fi

if [[ -z "$REF_FASTA" ]]; then
  REF_FASTA="$OUT_DIR/${REF_NAME}.fas"
fi

if [[ -z "$STRAINS_MATCH" ]]; then
  STRAINS_MATCH="$HPV_TYPE"
fi

if [[ -z "$BCF_RUN_ID" && -z "$BCF_DIR" && -f "$SAMPLES_TSV" ]]; then
  mapfile -t run_ids < <(
    awk -F'\t' '
      NR==1 && $1 ~ /^#/ {
        sub(/^#[[:space:]]*/, "", $1)
      }
      $1 ~ /^#/ { next }
      {
        run=$1
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", run)
        if (tolower(run) == "run_id") next
        if (run == "" || tolower(run) == "null") {
          n=split($2, parts, "/")
          last=parts[n]
          run=(tolower(last)=="fastq" && n>1) ? parts[n-1] : last
        }
        if (run != "") print run
      }
    ' "$SAMPLES_TSV" | sort -u
  )
  if [[ ${#run_ids[@]} -eq 1 ]]; then
    BCF_RUN_ID="${run_ids[0]}"
  elif [[ ${#run_ids[@]} -gt 1 ]]; then
    echo "Error: multiple run IDs in $SAMPLES_TSV; set BCF_RUN_ID or BCF_DIR explicitly." >&2
    exit 1
  fi
fi

if [[ -z "$BCF_DIR" && -n "$BCF_RUN_ID" ]]; then
  BCF_DIR="$MAPPING_OUTDIR/$BCF_RUN_ID"
fi

if [[ -n "$BCF_DIR" && ! -d "$BCF_DIR" ]]; then
  BCF_DIR=""
fi

if [[ -z "$BCF_RUN_ID" && -n "$BCF_DIR" ]]; then
  BCF_RUN_ID=$(basename "$BCF_DIR")
fi

if [[ -z "$BCF_DIR" && -d "$MAPPING_OUTDIR" ]]; then
  mapfile -t run_dirs < <(find "$MAPPING_OUTDIR" -mindepth 1 -maxdepth 1 -type d ! -name reports | sort)
  if [[ ${#run_dirs[@]} -eq 1 ]]; then
    BCF_DIR="${run_dirs[0]}"
    BCF_RUN_ID=$(basename "$BCF_DIR")
  fi
fi

if [[ -z "$BCF_DIR" ]]; then
  echo "Error: BCF_DIR is required (set BCF_DIR or BCF_RUN_ID, or ensure $SAMPLES_TSV exists with a single run ID)." >&2
  exit 1
fi

if ! command -v seqkit >/dev/null 2>&1; then
  echo "Error: seqkit is required but not found in PATH." >&2
  exit 1
fi

if ! command -v bcftools >/dev/null 2>&1; then
  echo "Error: bcftools is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$PAVE_FASTA" ]]; then
  echo "Error: missing PAVE FASTA: $PAVE_FASTA" >&2
  exit 1
fi

if [[ -z "$SAMPLES" && -n "$SAMPLES_FILE" ]]; then
  if [[ ! -f "$SAMPLES_FILE" ]]; then
    echo "Error: SAMPLES_FILE not found: $SAMPLES_FILE" >&2
    exit 1
  fi
  SAMPLES=$(tr '\n' ' ' < "$SAMPLES_FILE")
fi

if [[ -z "$SAMPLES" && -f "$STRAINS_TSV" && -n "$BCF_RUN_ID" ]]; then
  # Candidate samples: assigned this HPV type among their top strains.
  candidate_samples=$(awk -F'\t' -v run="$BCF_RUN_ID" -v hpv="$STRAINS_MATCH" \
    'NR>1 && $1==run && $2 ~ /^KHCA-/ && $4 ~ ("(^|,)"hpv"(,|$)") {print $2}' \
    "$STRAINS_TSV" | sort -u)

  if [[ -n "$candidate_samples" && -n "$MIN_COV_BREADTH" && -f "$COV_STATS_TSV" ]]; then
    # Keep only samples whose genome-wide breadth for this strain clears the
    # threshold, so low-coverage hits (a handful of stray reads) are dropped.
    SAMPLES=$(awk -F'\t' -v hpv="$HPV_TYPE" -v minb="$MIN_COV_BREADTH" '
        FNR==NR { cand[$1]=1; next }
        FNR==1 {
          for (i=1; i<=NF; i++) {
            if ($i=="sample") sc=i
            else if ($i=="strain") tc=i
            else if ($i=="avg_cov_breadth") bc=i
          }
          next
        }
        (sc && tc && bc && $tc==hpv && ($bc+0) >= (minb+0) && ($sc in cand)) { print $sc }
      ' <(printf '%s\n' "$candidate_samples") "$COV_STATS_TSV" | sort -u | xargs)

    dropped=$(comm -23 \
      <(printf '%s\n' "$candidate_samples" | sort -u) \
      <(printf '%s\n' $SAMPLES | tr ' ' '\n' | sort -u) | xargs)
    if [[ -n "$dropped" ]]; then
      echo "Info: excluded low-breadth ${HPV_TYPE} samples (avg_cov_breadth < ${MIN_COV_BREADTH}): $dropped" >&2
    fi
  else
    if [[ -n "$candidate_samples" ]]; then
      echo "Warning: coverage stats not found ($COV_STATS_TSV); skipping breadth filter." >&2
    fi
    SAMPLES=$(printf '%s\n' "$candidate_samples" | xargs)
  fi
fi

if [[ -z "$SAMPLES" && -f "$OUT_DIR/samples.fasta" ]]; then
  SAMPLES=$(awk -v hpv="$HPV_TYPE" '
    /^>/{
      h=substr($0,2);
      sub("-"hpv"$","",h);
      print h;
    }' "$OUT_DIR/samples.fasta" | sort -u | xargs)
fi

if [[ -z "$SAMPLES" ]]; then
  echo "Error: SAMPLES is empty; set SAMPLES or SAMPLES_FILE." >&2
  exit 1
fi

seqkit grep -r -p "$REF_PATTERN" "$PAVE_FASTA" > "$REF_FASTA"

consensus_dir="$OUT_DIR/samples_consensus"
mkdir -p "$consensus_dir"

# Reference contig id (first whitespace-delimited token of the FASTA header),
# used to pull this strain's per-base depth out of the genome-wide depth file.
ref_contig=$(awk 'sub(/^>/, ""){print $1; exit}' "$REF_FASTA")

read -r -a sample_list <<< "$SAMPLES"
for sample in "${sample_list[@]}"; do
  sample_id="$sample"
  if [[ "$sample_id" != KHCA-* ]]; then
    sample_id="KHCA-$sample_id"
  fi
  bcf_path="$BCF_DIR/${sample_id}.bcf.gz"
  out_path="$consensus_dir/${sample_id}.${REF_NAME}.consensus.fa"
  if [[ ! -f "$bcf_path" ]]; then
    echo "Error: missing BCF: $bcf_path" >&2
    exit 1
  fi

  # Mask positions below the minimum depth with N so uncovered regions are not
  # silently filled in with the reference base by `bcftools consensus`.
  consensus_mask_arg=()
  if [[ -n "$MIN_CONSENSUS_DEPTH" && "$MIN_CONSENSUS_DEPTH" != "0" ]]; then
    depth_path="$BCF_DIR/${sample_id}.depth"
    if [[ -f "$depth_path" && -n "$ref_contig" ]]; then
      mask_bed="$consensus_dir/${sample_id}.${REF_NAME}.lowcov.bed"
      awk -F'\t' -v c="$ref_contig" -v mind="$MIN_CONSENSUS_DEPTH" \
        'BEGIN{OFS="\t"} $1==c && ($3+0) < (mind+0) {print $1, $2-1, $2}' \
        "$depth_path" > "$mask_bed"
      if [[ -s "$mask_bed" ]]; then
        consensus_mask_arg=(--mask "$mask_bed" --mask-with N)
      fi
    else
      echo "Warning: depth file not found ($depth_path); consensus for ${sample_id} not coverage-masked." >&2
    fi
  fi

  if [[ ${#consensus_mask_arg[@]} -gt 0 ]]; then
    bcftools consensus -f "$REF_FASTA" "${consensus_mask_arg[@]}" "$bcf_path" > "$out_path"
  else
    bcftools consensus -f "$REF_FASTA" "$bcf_path" > "$out_path"
  fi

  tmp_out=$(mktemp)
  awk -v id="${sample_id}-${HPV_TYPE}" 'NR==1{print ">"id; next} {print}' "$out_path" > "$tmp_out"
  mv "$tmp_out" "$out_path"
done

samples_fasta="$OUT_DIR/samples.fasta"
: > "$samples_fasta"
for sample in "${sample_list[@]}"; do
  sample_id="$sample"
  if [[ "$sample_id" != KHCA-* ]]; then
    sample_id="KHCA-$sample_id"
  fi
  cat "$consensus_dir/${sample_id}.${REF_NAME}.consensus.fa" >> "$samples_fasta"
done
