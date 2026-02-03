#!/usr/bin/env python3
"""Build strain assignment + coverage table per sample."""

import csv
import sys
from pathlib import Path

NA = "NA"


def load_patients_metadata(path: Path):
    data = {}
    if not path.exists():
        return data
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            pid = (row.get("Patient study ID") or "").strip()
            if not pid:
                continue
            data[pid] = {
                "cin_status": (row.get("CIN2+ lesion") or "").strip() or NA,
                "age": (row.get("Age (year)") or "").strip() or NA,
                "last_cd4": (row.get("Last CD4-cell count") or "").strip() or NA,
                "cd4_nadir": (row.get("cd4nadir") or "").strip() or NA,
            }
    return data


def load_genexpert(path: Path):
    data = {}
    if not path.exists():
        return data
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            pid = (row.get("Patient study ID") or "").strip()
            if not pid:
                continue
            data[pid] = (row.get("HPV_genotype (Genexpert)") or "").strip() or NA
    return data


def load_cov_stats(path: Path):
    cov = {}
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            run = (row.get("run_id") or "").strip()
            sample = (row.get("sample") or "").strip()
            strain = (row.get("strain") or "").strip()
            if not (run and sample and strain):
                continue
            key = (run, sample)
            cov.setdefault(key, {})[strain] = {
                "genome": row.get("avg_cov_depth") or "",
                "e6": row.get("E6_avg_cov_depth") or "",
                "e7": row.get("E7_avg_cov_depth") or "",
            }
    return cov


def parse_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def avg(values):
    values = [v for v in values if v is not None]
    if not values:
        return NA
    return f"{sum(values) / len(values):.6f}"


def build_report(strains_path: Path, cov_path: Path, patients_path: Path, genexpert_path: Path, out_path: Path):
    patients = load_patients_metadata(patients_path)
    genexpert = load_genexpert(genexpert_path)
    cov = load_cov_stats(cov_path)

    with strains_path.open(newline="") as handle, out_path.open("w", newline="") as out:
        reader = csv.DictReader(handle, delimiter="\t")
        writer = csv.writer(out, delimiter="\t")
        writer.writerow([
            "Patient ID",
            "CIN status",
            "Age",
            "Last CD4 count",
            "CD4 nadir",
            "Top strains",
            "Average Genome coverage of top strains",
            "Average E6 coverage of top strains",
            "Average E7 coverage of top strains",
            "GeneXpert results",
        ])

        for row in reader:
            run = (row.get("run") or "").strip()
            sample = (row.get("sample") or "").strip()
            if not sample:
                continue
            top_strains = (row.get("top_strains") or "").strip()
            if not top_strains or top_strains.upper() == "NA":
                strains_list = []
                top_strains = NA
            else:
                strains_list = [s.strip() for s in top_strains.split(",") if s.strip()]

            cov_rows = cov.get((run, sample), {})
            genome_vals = [parse_float(cov_rows.get(s, {}).get("genome")) for s in strains_list]
            e6_vals = [parse_float(cov_rows.get(s, {}).get("e6")) for s in strains_list]
            e7_vals = [parse_float(cov_rows.get(s, {}).get("e7")) for s in strains_list]

            patient_meta = patients.get(sample, {})
            writer.writerow([
                sample,
                patient_meta.get("cin_status", NA),
                patient_meta.get("age", NA),
                patient_meta.get("last_cd4", NA),
                patient_meta.get("cd4_nadir", NA),
                top_strains,
                avg(genome_vals),
                avg(e6_vals),
                avg(e7_vals),
                genexpert.get(sample, NA),
            ])


def main():
    if len(sys.argv) != 6:
        print(
            "usage: strain_assignment_coverage_report.py <strains.tsv> <cov_stats.tsv> <patients_metadata.txt> <genexpert_results.txt> <output.tsv>",
            file=sys.stderr,
        )
        sys.exit(1)

    strains_path = Path(sys.argv[1])
    cov_path = Path(sys.argv[2])
    patients_path = Path(sys.argv[3])
    genexpert_path = Path(sys.argv[4])
    out_path = Path(sys.argv[5])
    build_report(strains_path, cov_path, patients_path, genexpert_path, out_path)


if __name__ == "__main__":
    main()
