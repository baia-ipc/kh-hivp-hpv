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
params.pave_bed_dir = params.pave_bed_dir ?: "${projectRoot}/derived_data/refdata/pave/bed"
params.pave_gff3_dir = params.pave_gff3_dir ?: "${projectRoot}/refdata/pave/gff3"
params.lineage_hpv16_fasta = params.lineage_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta"
params.lineage_hpv18_fasta = params.lineage_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta"
params.lineage_ref_hpv16_name = params.lineage_ref_hpv16_name ?: "HPV16REF|lcl|Human"
params.lineage_ref_hpv18_name = params.lineage_ref_hpv18_name ?: "HPV18REF|lcl|Human"
params.pave_ref_fasta = params.pave_ref_fasta ?: "${projectRoot}/refdata/pave/pave_hsa.fas"
params.include_lineage = params.containsKey('include_lineage') ? params.include_lineage : true

if (!params.containsKey('mapping_outdir')) params.mapping_outdir = null
if (!params.containsKey('reports_dir')) params.reports_dir = null

[ 'mapping_outdir', 'reports_dir', 'scripts_dir', 'pave_bed_dir', 'pave_gff3_dir',
  'index_dir', 'pave_ref_fasta'
].each { key ->
    if (!params[key]) {
        error "params.${key} is required"
    }
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

    def lineage_compare = null
    if (params.include_lineage) {
        def lineage_snps = LINEAGE_SNPS(bedReady)
        lineage_compare = COMPARE_LINEAGE_SNPS(variants, lineage_snps)
    }

    def reports_done = variants.mix(variant_effects)
    if (lineage_compare) {
        reports_done = reports_done.mix(lineage_compare)
    }
    reports_done = reports_done.collect()

    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, reports_done)
}
