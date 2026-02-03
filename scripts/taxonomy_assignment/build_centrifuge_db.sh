#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build a Centrifuge index from human (GRCh) + RefSeq archaea/bacteria/viral sequences.

Usage:
  scripts/taxonomy_assignment/build_centrifuge_db.sh [--outdir DIR] [--taxonomy-date YYYY-MM-DD]
                                 [--index-name NAME] [--threads N]
                                 [--refseq-domains LIST]

Defaults:
  --outdir         refdata/centrifuge
  --taxonomy-date  (none; output dir will be refdata/centrifuge/taxonomy/)
  --index-name     human_abv
  --threads        $THREADS or 24
  --refseq-domains archaea,bacteria,viral

Notes:
  - Requires centrifuge-download and centrifuge-build in PATH.
  - The resulting index base path will be <outdir>/<index-name>.
  - This script downloads the NCBI taxonomy dump, human reference genome
    sequences (taxid 9606, RefSeq), and RefSeq sequences from the requested
    domain list (default: archaea, bacteria, viral).

EOF
}

OUTDIR="refdata/centrifuge"
TAXONOMY_DATE=""
INDEX_NAME="human_abv"
THREADS="${THREADS:-24}"
REFSEQ_DOMAINS="archaea,bacteria,viral"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir)
      OUTDIR="$2"
      shift 2
      ;;
    --taxonomy-date)
      TAXONOMY_DATE="$2"
      shift 2
      ;;
    --index-name)
      INDEX_NAME="$2"
      shift 2
      ;;
    --threads|-p)
      THREADS="$2"
      shift 2
      ;;
    --refseq-domains)
      REFSEQ_DOMAINS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TAXDIR="${OUTDIR}/taxonomy${TAXONOMY_DATE:+-${TAXONOMY_DATE}}"
LIBDIR="${OUTDIR}/library"
MAP="${OUTDIR}/seqid2taxid.map"
FASTA="${OUTDIR}/library.fna"
INDEX_BASE="${OUTDIR}/${INDEX_NAME}"

mkdir -p "${OUTDIR}" "${LIBDIR}"

echo "[centrifuge] Downloading taxonomy to ${TAXDIR}"
centrifuge-download -o "${TAXDIR}" taxonomy

echo "[centrifuge] Downloading human (taxid 9606, RefSeq) sequences"
: > "${MAP}"
centrifuge-download \
  -o "${LIBDIR}/human" \
  -d "vertebrate_mammalian" \
  -a "Chromosome" \
  -t 9606 \
  -c "reference genome" \
  refseq >> "${MAP}"

echo "[centrifuge] Downloading RefSeq sequences (${REFSEQ_DOMAINS})"
centrifuge-download \
  -o "${LIBDIR}/refseq" \
  -d "${REFSEQ_DOMAINS}" \
  refseq >> "${MAP}"

echo "[centrifuge] Building combined FASTA at ${FASTA}"
: > "${FASTA}"
while IFS= read -r -d '' fasta; do
  case "${fasta}" in
    *.gz) gzip -dc "${fasta}" >> "${FASTA}" ;;
    *) cat "${fasta}" >> "${FASTA}" ;;
  esac
done < <(find "${LIBDIR}" -type f \( -name '*.fna' -o -name '*.fa' -o -name '*.fna.gz' -o -name '*.fa.gz' \) -print0)

echo "[centrifuge] Building index at ${INDEX_BASE}"
centrifuge-build \
  -p "${THREADS}" \
  --conversion-table "${MAP}" \
  --taxonomy-tree "${TAXDIR}/nodes.dmp" \
  --name-table "${TAXDIR}/names.dmp" \
  "${FASTA}" \
  "${INDEX_BASE}"

echo "[centrifuge] Done."
