#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/pipelines/conda_env/pipeline.env.yml"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/variant_analysis.multiqc.yml"
params.include_database = params.containsKey('include_database') ? params.include_database : false
params.pave_bed_dir = params.pave_bed_dir ?: "${projectRoot}/derived_data/refdata/pave/bed"
params.pave_gff3_dir = params.pave_gff3_dir ?: "${projectRoot}/refdata/pave/gff3"
params.lineage_hpv16_fasta = params.lineage_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta"
params.lineage_hpv18_fasta = params.lineage_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta"
params.lineage_ref_hpv16_name = params.lineage_ref_hpv16_name ?: "HPV16REF|lcl|Human"
params.lineage_ref_hpv18_name = params.lineage_ref_hpv18_name ?: "HPV18REF|lcl|Human"
params.pave_ref_fasta = params.pave_ref_fasta ?: "${projectRoot}/refdata/pave/pave_hsa.fas"
params.include_lineage = params.containsKey('include_lineage') ? params.include_lineage : true
params.target_country = params.target_country ?: "Cambodia"
params.selected_hpv16_fasta = params.selected_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/selected.fasta"
params.selected_hpv16_tsv = params.selected_hpv16_tsv ?: "${projectRoot}/derived_data/refdata/hpv16_tree/selected"
params.selected_hpv18_fasta = params.selected_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/selected.fasta"
params.selected_hpv18_tsv = params.selected_hpv18_tsv ?: "${projectRoot}/derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv"

if (!params.containsKey('mapping_outdir')) params.mapping_outdir = null
if (!params.containsKey('reports_dir')) params.reports_dir = null
if (!params.containsKey('samples_tsv')) params.samples_tsv = null
if (!params.containsKey('database_outdir')) params.database_outdir = null

[ 'mapping_outdir', 'reports_dir', 'scripts_dir', 'pave_bed_dir', 'pave_gff3_dir',
  'index_dir', 'pave_ref_fasta'
].each { key ->
    if (!params[key]) {
        error "params.${key} is required"
    }
}

if (params.include_database && !params.include_lineage) {
    error "include_database requires include_lineage=true"
}

if (params.include_database) {
    [ 'selected_hpv16_fasta', 'selected_hpv16_tsv', 'selected_hpv18_fasta', 'selected_hpv18_tsv',
      'samples_tsv'
    ].each { key ->
        if (!params[key]) {
            error "params.${key} is required when include_database=true"
        }
    }
}

if (params.include_database && !params.database_outdir) {
    def reportsPath = Paths.get(params.reports_dir.toString())
    params.database_outdir = reportsPath.getParent().resolve("output/database_snps").normalize().toString()
}

if (params.include_lineage) {
    [ 'lineage_hpv16_fasta', 'lineage_hpv18_fasta', 'lineage_ref_hpv16_name', 'lineage_ref_hpv18_name' ].each { key ->
        if (!params[key]) {
            error "params.${key} is required when include_lineage=true"
        }
    }
}


def checkPath(String path, String label, boolean mustBeDir = false) {
    def target = new File(path)
    if (mustBeDir) {
        if (!target.isDirectory()) {
            error "${label} is not a directory: ${path}"
        }
    } else if (!target.exists()) {
        error "${label} not found: ${path}"
    }
}

checkPath(params.mapping_outdir as String, 'Mapping output directory', true)
checkPath(params.pave_gff3_dir as String, 'PAVE GFF3 directory', true)
checkPath(params.scripts_dir as String, 'Scripts directory', true)
checkPath(params.pave_ref_fasta as String, 'PAVE reference fasta')
if (params.include_lineage) {
    checkPath(params.lineage_hpv16_fasta as String, 'HPV16 lineages reference FASTA')
    checkPath(params.lineage_hpv18_fasta as String, 'HPV18 lineages reference FASTA')
}

if (params.include_database) {
    checkPath(params.selected_hpv16_fasta as String, 'HPV16 selected fasta')
    checkPath(params.selected_hpv16_tsv as String, 'HPV16 selected metadata')
    checkPath(params.selected_hpv18_fasta as String, 'HPV18 selected fasta')
    checkPath(params.selected_hpv18_tsv as String, 'HPV18 selected metadata')
    checkPath(params.samples_tsv as String, 'Samples metadata TSV')
}


def bedDir = new File(params.pave_bed_dir as String)
if (bedDir.exists() && !bedDir.isDirectory()) {
    error "BED directory path is not a directory: ${params.pave_bed_dir}"
}

def bedReady = (bedDir.isDirectory() && bedDir.listFiles()?.any { it.name.endsWith('.bed') }) \
    ? Channel.value(true) \
    : null

process GENERATE_BED {
    tag "bed"
    publishDir "${params.pave_bed_dir}", mode: 'copy'

    input:
    val(dummy)

    output:
    path "*.bed", emit: beds

    script:
    """
    "${params.scripts_dir}/pave/gff3_to_bed.run_all.sh" "${params.pave_gff3_dir}" .
    """
}

process EXTRACT_DATABASE {
    tag "extract"
    publishDir "${params.database_outdir}", mode: 'copy'
    conda params.conda_env

    input:
    path(hpv16_fasta, stageAs: 'hpv16_selected.fasta')
    path(hpv16_tsv, stageAs: 'hpv16_selected.tsv')
    path(hpv18_fasta, stageAs: 'hpv18_selected.fasta')
    path(hpv18_tsv, stageAs: 'hpv18_selected.tsv')

    output:
    tuple path('database_hpv16.fasta'), path('database_hpv18.fasta')

    script:
    """
    "${params.scripts_dir}/phylo_tree/extract_country_sequences.py" \\
      --selected-fasta "${hpv16_fasta}" \\
      --selected-metadata "${hpv16_tsv}" \\
      --country "${params.target_country}" \\
      --label-prefix "HPV16" \\
      --output database_hpv16.fasta

    "${params.scripts_dir}/phylo_tree/extract_country_sequences.py" \\
      --selected-fasta "${hpv18_fasta}" \\
      --selected-metadata "${hpv18_tsv}" \\
      --country "${params.target_country}" \\
      --label-prefix "HPV18" \\
      --output database_hpv18.fasta
    """
}

process DATABASE_SNPS {
    tag "database_snps"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    tuple path(database_hpv16), path(database_hpv18)
    val(bed_ready)

    output:
    path('database_snps.tsv')

    script:
    """
    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${database_hpv16}" \\
      --ref "${params.pave_ref_fasta}" \\
      --ref-name "${params.lineage_ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > database_snps.tsv

    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${database_hpv18}" \\
      --ref "${params.pave_ref_fasta}" \\
      --ref-name "${params.lineage_ref_hpv18_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      >> database_snps.tsv
    """
}

process COMPARE_DATABASE_LINEAGES {
    tag "database_vs_lineages"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(database_snps)
    path(lineage_snps)

    output:
    path('database_lineage_comparison.tsv')

    script:
    """
    "${params.scripts_dir}/variants/compare_query_snps_to_lineages.py" \\
      --query-snps "${database_snps}" \\
      --lineage-snps "${lineage_snps}" \\
      --output database_lineage_comparison.tsv
    """
}

process COMPARE_DATABASE_SAMPLES {
    tag "database_vs_samples"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(database_snps)
    path(sample_variants)

    output:
    path('database_sample_comparison.tsv')

    script:
    """
    "${params.scripts_dir}/variants/compare_query_snps_to_samples.py" \\
      --query-snps "${database_snps}" \\
      --variants "${sample_variants}" \\
      --output database_sample_comparison.tsv
    """
}

process COMPARE_SAMPLES_DATABASE {
    tag "samples_vs_database"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(database_snps)
    path(sample_variants)

    output:
    path('samples_vs_database.tsv')

    script:
    """
    "${params.scripts_dir}/variants/compare_samples_to_query_snps.py" \\
      --variants "${sample_variants}" \\
      --query-snps "${database_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_database.tsv
    """
}

process COMPARE_SNP_SETS_DATABASE {
    tag "samples_vs_database_sets"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(database_snps)
    path(sample_variants)
    path(compare_script)

    output:
    path('samples_vs_database_sets.tsv')

    script:
    """
    python "${compare_script}" \\
      --variants "${sample_variants}" \\
      --database-snps "${database_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_database_sets.tsv
    """
}

process COMPARE_SNP_SETS_LINEAGES {
    tag "samples_vs_lineage_sets"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(lineage_snps)
    path(sample_variants)
    path(compare_script)

    output:
    path('samples_vs_lineage_sets.tsv')

    script:
    """
    python "${compare_script}" \\
      --variants "${sample_variants}" \\
      --lineage-snps "${lineage_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_lineage_sets.tsv
    """
}

process HPV16_E6E7_SUMMARY {
    tag "hpv16_e6e7_summary"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(sample_variant_effects)
    path(sample_list)
    path(database_snps)
    path(lineage_snps)
    path(database_fasta)
    path(lineage_fasta)

    output:
    path('hpv16_e6e7_variants_summary.tsv')

    script:
    """
    "${params.scripts_dir}/variants/summarize_hpv16_e6e7_variants_database.py" \\
      --sample-effects "${sample_variant_effects}" \\
      --sample-list "${sample_list}" \\
      --database-snps "${database_snps}" \\
      --lineage-snps "${lineage_snps}" \\
      --database-fasta "${database_fasta}" \\
      --lineage-fasta "${lineage_fasta}" \\
      --ref-fasta "${params.pave_ref_fasta}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --output hpv16_e6e7_variants_summary.tsv
    """
}

process PREPARE_DATABASE_MULTIQC {
    tag "multiqc_tables"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(database_snps)
    path(database_lineage_comparison)
    path(database_sample_comparison)
    path(samples_vs_database)
    path(samples_vs_database_sets)
    path(samples_vs_lineage_sets)
    path(hpv16_e6e7_summary)

    output:
    tuple path('database_snps.multiqc.tsv'),
          path('database_lineage_comparison.multiqc.tsv'),
          path('database_sample_comparison.multiqc.tsv'),
          path('samples_vs_database.multiqc.tsv'),
          path('samples_vs_database_sets.multiqc.tsv'),
          path('samples_vs_lineage_sets.multiqc.tsv'),
          path('hpv16_e6e7_variants_summary.multiqc.tsv')

    script:
    """
    python - <<'PY'
    import csv

    def prepare(input_path, output_path, id_builder):
        with open(input_path, newline='') as handle:
            reader = csv.reader(handle, delimiter='\\t')
            rows = list(reader)
        if not rows:
            with open(output_path, 'w', newline='') as out:
                writer = csv.writer(out, delimiter='\\t')
                writer.writerow(['ID', 'database_id', 'gene', 'chrom', 'pos', 'ref', 'alt'])
            return
        header = rows[0]
        start_idx = 1 if header and header[0] in ('lineage', 'database_id', 'query_id', 'sample') else 0
        if start_idx == 0:
            header = ['database_id', 'gene', 'chrom', 'pos', 'ref', 'alt'] + header[6:]
        else:
            header = header[:]
            if header[0] in ('lineage', 'query_id', 'sample'):
                header[0] = 'database_id'
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\\t')
            writer.writerow(['ID'] + header)
            for row in rows[start_idx:]:
                if len(row) < 6:
                    continue
                database_id, gene, chrom, pos, ref, alt = row[:6]
                extra = row[6:]
                row_id = id_builder(database_id, gene, pos, ref, alt)
                writer.writerow([row_id, database_id, gene, chrom, pos, ref, alt] + extra)

    def build_id(database_id, gene, pos, ref, alt):
        return f"{database_id}:{gene}:{ref}{pos}{alt}"

    prepare('database_snps.tsv', 'database_snps.multiqc.tsv', build_id)
    prepare('database_lineage_comparison.tsv', 'database_lineage_comparison.multiqc.tsv', build_id)
    prepare('database_sample_comparison.tsv', 'database_sample_comparison.multiqc.tsv', build_id)
    def prepare_samples(input_path, output_path):
        with open(input_path, newline='') as handle:
            reader = csv.reader(handle, delimiter='\\t')
            rows = list(reader)
        if not rows:
            with open(output_path, 'w', newline='') as out:
                writer = csv.writer(out, delimiter='\\t')
                writer.writerow(['ID', 'run', 'sample', 'gene', 'chrom', 'pos', 'ref', 'alt'])
            return
        header = rows[0]
        start_idx = 1 if header and header[0] == 'run' else 0
        if start_idx == 0:
            header = ['run', 'sample', 'gene', 'chrom', 'pos', 'ref', 'alt'] + header[7:]
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\\t')
            writer.writerow(['ID'] + header)
            for row in rows[start_idx:]:
                if len(row) < 7:
                    continue
                run, sample, gene, chrom, pos, ref, alt = row[:7]
                extra = row[7:]
                row_id = f\"{run}:{sample}:{gene}:{ref}{pos}{alt}\"
                writer.writerow([row_id, run, sample, gene, chrom, pos, ref, alt] + extra)

    prepare_samples('samples_vs_database.tsv', 'samples_vs_database.multiqc.tsv')

    def prepare_set_comparison(input_path, output_path, label_field):
        with open(input_path, newline='') as handle:
            reader = csv.reader(handle, delimiter='\\t')
            rows = list(reader)
        if not rows:
            with open(output_path, 'w', newline='') as out:
                writer = csv.writer(out, delimiter='\\t')
                writer.writerow(['ID', 'run', 'sample', label_field])
            return
        header = rows[0]
        start_idx = 1 if header and header[0] == 'run' else 0
        if start_idx == 0:
            header = ['run', 'sample', label_field] + header[3:]
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\\t')
            writer.writerow(['ID'] + header)
            for row in rows[start_idx:]:
                if len(row) < 3:
                    continue
                run, sample, label = row[:3]
                extra = row[3:]
                row_id = f\"{run}:{sample}:{label}\"
                writer.writerow([row_id, run, sample, label] + extra)

    prepare_set_comparison('samples_vs_database_sets.tsv', 'samples_vs_database_sets.multiqc.tsv', 'database_id')
    prepare_set_comparison('samples_vs_lineage_sets.tsv', 'samples_vs_lineage_sets.multiqc.tsv', 'lineage')

    import shutil
    shutil.copyfile('hpv16_e6e7_variants_summary.tsv', 'hpv16_e6e7_variants_summary.multiqc.tsv')
    PY
    """
}

process AGGREGATE_VARIANTS {
    tag "aggregate_variants"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(bed_ready)

    output:
    path "E6_E7_variants.tsv"

    script:
    """
    "${params.scripts_dir}/variants/report_E6_E7_variants.sh" "${params.mapping_outdir}" "${params.pave_bed_dir}" > "E6_E7_variants.tsv"
    """
}

process AGGREGATE_VARIANT_EFFECTS {
    tag "aggregate_variant_effects"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(bed_ready)

    output:
    path "E6_E7_variant_effects.tsv"

    script:
    """
    "${params.scripts_dir}/variants/report_E6_E7_variant_effects.sh" "${params.mapping_outdir}" "${params.pave_bed_dir}" "${params.pave_gff3_dir}" "${params.index_dir}/pave_hsa.fas" > "E6_E7_variant_effects.tsv"
    """
}

process LINEAGE_SNPS {
    tag "lineage_snps"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(bed_ready)

    output:
    path "lineage_snps.tsv"

    when:
    params.include_lineage

    script:
    """
    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${params.lineage_hpv16_fasta}" \\
      --ref "${params.pave_ref_fasta}" \\
      --ref-name "${params.lineage_ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > lineage_snps.tsv

    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${params.lineage_hpv18_fasta}" \\
      --ref "${params.pave_ref_fasta}" \\
      --ref-name "${params.lineage_ref_hpv18_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      >> lineage_snps.tsv
    """
}

process COMPARE_LINEAGE_SNPS {
    tag "compare_lineage_snps"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    path variants
    path lineage_snps

    output:
    path "lineage_snp_comparison.tsv"

    when:
    params.include_lineage

    script:
    """
    "${params.scripts_dir}/variants/compare_lineage_snps.py" \\
      --variants "${variants}" \\
      --lineage-snps "${lineage_snps}" \\
      --output "lineage_snp_comparison.tsv"
    """
}

process MULTIQC {
    tag "multiqc"
    conda params.conda_env
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    path(multiqc_config)
    path(done)

    output:
    path("multiqc_report.html")
    path("E6_E7_variants.multiqc.tsv")
    path("E6_E7_variant_effects.multiqc.tsv")
    path("lineage_snp_comparison.multiqc.tsv"), optional: true

    script:
    """
    cp "${params.reports_dir}/E6_E7_variants.tsv" .
    cp "${params.reports_dir}/E6_E7_variant_effects.tsv" .
    if [ -f "${params.reports_dir}/lineage_snp_comparison.tsv" ]; then
      cp "${params.reports_dir}/lineage_snp_comparison.tsv" .
    fi

    python - <<'PY'
import csv
import os
import re
import urllib.parse

def normalize_header(header, ncols):
    if len(header) < ncols:
        header = header + [f"col{i}" for i in range(len(header) + 1, ncols + 1)]
    elif len(header) > ncols:
        header = header[:ncols]
    return header

def find_col_idx(header, name):
    if not header:
        return None
    for idx, col in enumerate(header):
        if col.lower() == name:
            return idx
    return None

def strip_transcript_name(value):
    if not value:
        return ""
    name = value
    if "_" in name:
        name = name.split("_", 1)[1]
    if name.endswith(".mRNA"):
        name = name[:-5]
    return name

def format_aa_change(value, consequence):
    if not value:
        if consequence:
            return consequence
        return "unknown"
    m = re.match(r"(\\d+)([A-Za-z*])>(\\d+)([A-Za-z*])", value)
    if m:
        pos1, ref, pos2, alt = m.groups()
        if pos1 == pos2:
            return f"{ref}{pos1}{alt}"
    return value

def is_undetermined(row):
    if not row or len(row) < 2:
        return False
    sample = row[1]
    return sample.startswith("Undetermined")

def build_variant_id(row, header):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    gene = row[2] if len(row) > 2 else ""
    transcript_idx = find_col_idx(header, "transcript")
    strain_idx = find_col_idx(header, "strain")
    if strain_idx is None:
        strain_idx = find_col_idx(header, "chrom")
    pos_idx = find_col_idx(header, "pos")
    ref_idx = find_col_idx(header, "ref")
    alt_idx = find_col_idx(header, "alt")
    transcript = row[transcript_idx] if transcript_idx is not None and len(row) > transcript_idx else ""
    strain = row[strain_idx] if strain_idx is not None and len(row) > strain_idx else ""
    if "REF" in strain:
        strain = strain.split("REF", 1)[0]
    pos = row[pos_idx] if pos_idx is not None and len(row) > pos_idx else ""
    ref = row[ref_idx] if ref_idx is not None and len(row) > ref_idx else ""
    alt = row[alt_idx] if alt_idx is not None and len(row) > alt_idx else ""
    mut = f"{ref}{pos}{alt}" if ref and alt else pos
    return f"{run}:{sample}:{strain}:{gene}:{mut}"

def build_variant_effect_id(row, header):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    gene = row[2] if len(row) > 2 else ""
    transcript_idx = find_col_idx(header, "transcript")
    strain_idx = find_col_idx(header, "strain")
    if strain_idx is None:
        strain_idx = find_col_idx(header, "chrom")
    pos_idx = find_col_idx(header, "pos")
    ref_idx = find_col_idx(header, "ref")
    alt_idx = find_col_idx(header, "alt")
    aa_idx = find_col_idx(header, "amino_acid_change")
    consequence_idx = find_col_idx(header, "consequence")

    transcript = row[transcript_idx] if transcript_idx is not None and len(row) > transcript_idx else ""
    gene_label = strip_transcript_name(transcript) or gene
    strain = row[strain_idx] if strain_idx is not None and len(row) > strain_idx else ""
    if "REF" in strain:
        strain = strain.split("REF", 1)[0]
    pos = row[pos_idx] if pos_idx is not None and len(row) > pos_idx else ""
    ref = row[ref_idx] if ref_idx is not None and len(row) > ref_idx else ""
    alt = row[alt_idx] if alt_idx is not None and len(row) > alt_idx else ""
    mut = f"{ref}{pos}{alt}" if ref and alt else pos
    aa = row[aa_idx] if aa_idx is not None and len(row) > aa_idx else ""
    consequence = row[consequence_idx] if consequence_idx is not None and len(row) > consequence_idx else ""
    aa_label = format_aa_change(aa, consequence)
    return f"{run}:{sample}:{strain}:{gene_label}:{mut}:{aa_label}"

def decode_row(row, header, columns):
    if not columns or not header:
        return row
    header_map = {name.lower(): idx for idx, name in enumerate(header)}
    for name in columns:
        idx = header_map.get(name.lower())
        if idx is None or idx >= len(row):
            continue
        value = row[idx]
        if value:
            row[idx] = urllib.parse.unquote(value)
    return row

def rewrite_with_header(src, dest, id_builder=None, decode_cols=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        header = next(reader, None)
        if not header:
            return
        writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            if id_builder in (build_variant_effect_id, build_variant_id) and is_undetermined(row):
                continue
            row = decode_row(row, header, decode_cols)
            if id_builder:
                sample = id_builder(row, header)
            else:
                sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)

def rewrite_no_header(src, dest, header, id_builder=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\t')
        writer = csv.writer(out, delimiter='\t')
        first = next(reader, None)
        if not first:
            return
        header = normalize_header(header, len(first))
        writer.writerow(['Sample'] + header)
        if id_builder == build_variant_id and is_undetermined(first):
            first = None
        if id_builder:
            if first is not None:
                sample = id_builder(first, header)
            else:
                sample = None
        else:
            sample = f"{first[0]}:{first[1]}" if len(first) > 1 else first[0]
        if first is not None:
            writer.writerow([sample] + first)
        for row in reader:
            if not row:
                continue
            if id_builder == build_variant_id and is_undetermined(row):
                continue
            if id_builder:
                sample = id_builder(row, header)
            else:
                sample = f"{row[0]}:{row[1]}" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)

rewrite_no_header(
    'E6_E7_variants.tsv',
    'E6_E7_variants.multiqc.tsv',
    ['run', 'sample', 'gene', 'chrom', 'pos', 'id', 'ref', 'alt', 'qual', 'filter', 'info', 'format', 'sample_field'],
    id_builder=build_variant_id,
)
rewrite_with_header(
    'E6_E7_variant_effects.tsv',
    'E6_E7_variant_effects.multiqc.tsv',
    id_builder=build_variant_effect_id,
    decode_cols=['gene', 'transcript'],
)
rewrite_with_header(
    'lineage_snp_comparison.tsv',
    'lineage_snp_comparison.multiqc.tsv',
    id_builder=build_variant_id,
)
PY

    multiqc --force \\
      --filename "multiqc_report.html" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.reports_dir}"
    """
}

workflow {
    def multiqc_config_path = new File(params.multiqc_config)
    if (!multiqc_config_path.exists()) {
        error "MultiQC config not found: ${params.multiqc_config}"
    }

    if (!bedReady) {
        bedReady = GENERATE_BED(Channel.value(true)).beds.map { true }
    }

    def variants = AGGREGATE_VARIANTS(bedReady)
    def variant_effects = AGGREGATE_VARIANT_EFFECTS(bedReady)

    def lineage_snps = null
    def lineage_compare = null
    if (params.include_lineage) {
        lineage_snps = LINEAGE_SNPS(bedReady)
        lineage_compare = COMPARE_LINEAGE_SNPS(variants, lineage_snps)
    }

    def reports_done = variants.mix(variant_effects)
    if (lineage_compare) {
        reports_done = reports_done.mix(lineage_compare)
    }

    if (params.include_database) {
        def hpv16_fasta = file(params.selected_hpv16_fasta)
        def hpv16_tsv = file(params.selected_hpv16_tsv)
        def hpv18_fasta = file(params.selected_hpv18_fasta)
        def hpv18_tsv = file(params.selected_hpv18_tsv)
        def lineage_hpv16 = file(params.lineage_hpv16_fasta)
        def lineage_hpv18 = file(params.lineage_hpv18_fasta)
        def sample_list = file(params.samples_tsv)

        def database_fastas = EXTRACT_DATABASE(hpv16_fasta, hpv16_tsv, hpv18_fasta, hpv18_tsv)
        def database_snps = DATABASE_SNPS(database_fastas, bedReady)
        def database_lineages = COMPARE_DATABASE_LINEAGES(database_snps, lineage_snps)
        def database_samples = COMPARE_DATABASE_SAMPLES(database_snps, variants)
        def samples_vs_database = COMPARE_SAMPLES_DATABASE(database_snps, variants)
        def compare_database_sets = file("${params.scripts_dir}/variants/compare_sample_snp_sets_to_database.py")
        def compare_lineage_sets = file("${params.scripts_dir}/variants/compare_sample_snp_sets_to_lineages.py")
        def samples_vs_database_sets = COMPARE_SNP_SETS_DATABASE(database_snps, variants, compare_database_sets)
        def samples_vs_lineage_sets = COMPARE_SNP_SETS_LINEAGES(lineage_snps, variants, compare_lineage_sets)
        def database_hpv16 = database_fastas.map { it[0] }
        def hpv16_summary = HPV16_E6E7_SUMMARY(variant_effects, sample_list, database_snps, lineage_snps, database_hpv16, lineage_hpv16)
        def multiqc_tables = PREPARE_DATABASE_MULTIQC(database_snps, database_lineages, database_samples, samples_vs_database, samples_vs_database_sets, samples_vs_lineage_sets, hpv16_summary)
        reports_done = reports_done.mix(database_snps, database_lineages, database_samples, samples_vs_database, samples_vs_database_sets, samples_vs_lineage_sets, hpv16_summary, multiqc_tables)
    }

    reports_done = reports_done.collect()

    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, reports_done)
}
