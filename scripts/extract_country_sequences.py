#!/usr/bin/env python3
"""Extract sequences for a target country from a selected FASTA + metadata TSV."""
import argparse
import csv


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selected-fasta", required=True, help="Selected FASTA file")
    parser.add_argument("--selected-metadata", required=True, help="TSV with Accession and Country")
    parser.add_argument("--country", required=True, help="Country name to filter")
    parser.add_argument("--label-prefix", default="", help="Prefix to add to sequence IDs")
    parser.add_argument("--output", required=True, help="Output FASTA")
    return parser.parse_args()


def normalize_accession(value):
    if not value:
        return ""
    return value.split(".")[0].strip()


def load_accessions(path, country):
    accessions = set()
    with open(path, newline="") as handle:
        first = handle.readline()
        if not first:
            return accessions
        handle.seek(0)
        header = first.rstrip().split("\t")
        if header and header[0].lower() == "accession":
            reader = csv.DictReader(handle, delimiter="\t")
            for row in reader:
                acc = normalize_accession(row.get("Accession", ""))
                row_country = (row.get("Country", "") or "").strip()
                if acc and row_country.lower() == country.lower():
                    accessions.add(acc)
        else:
            reader = csv.reader(handle, delimiter="\t")
            for row in reader:
                if len(row) < 2:
                    continue
                acc = normalize_accession(row[0])
                row_country = (row[1] or "").strip()
                if acc and row_country.lower() == country.lower():
                    accessions.add(acc)
    return accessions


def read_fasta(path):
    name = None
    seq = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if name is not None:
                    yield name, "".join(seq)
                name = line[1:].split()[0]
                seq = []
            else:
                seq.append(line)
        if name is not None:
            yield name, "".join(seq)


def main():
    args = parse_args()
    accessions = load_accessions(args.selected_metadata, args.country)
    prefix = args.label_prefix.strip()
    if prefix:
        prefix = f"{prefix}_"

    with open(args.output, "w") as out:
        for header, seq in read_fasta(args.selected_fasta):
            accession = normalize_accession(header)
            if accession in accessions:
                out.write(f">{prefix}{accession}\n{seq}\n")


if __name__ == "__main__":
    main()
