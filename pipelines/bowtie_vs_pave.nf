#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def normalizeSampleId(String filename) {
    def base = filename
    base = base.replaceFirst(/\.fastq(\.gz)?$/, '')
    base = base.replaceFirst(/\.R1\..*$/, '')
    base = base.replaceFirst(/_R1_.*$/, '')
    base = base.replaceFirst(/_S\d+_.*/, '')
    return base
}

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/bowtie_vs_pave.multiqc.yml"
params.lineage_hpv16_fasta = params.lineage_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta"
params.lineage_hpv18_fasta = params.lineage_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta"
params.lineage_ref_hpv16_name = params.lineage_ref_hpv16_name ?: "HPV16REF|lcl|Human"
params.lineage_ref_hpv18_name = params.lineage_ref_hpv18_name ?: "HPV18REF|lcl|Human"
// Avoid "Access to undefined parameter" warnings; these are optional filters/inputs.
if (!params.containsKey('reads_dir'))  params.reads_dir = null
if (!params.containsKey('read1'))      params.read1 = null
if (!params.containsKey('read2'))      params.read2 = null
if (!params.containsKey('run_id'))     params.run_id = null
if (!params.containsKey('sample_id'))  params.sample_id = null

def bucketTid = params.bucket_tid
if (!bucketTid) {
    error "params.bucket_tid is required"
}
params.bucket_tid = bucketTid

def requiredParams = [
    'index_dir',
    'outdir',
    'reports_dir',
    'bucket_tid',
    'pave_ref_fasta',
    'pave_gff3_dir',
    'features_tsv_dir',
    'pave_bed_dir',
    'scripts_dir',
    'lineage_hpv16_fasta',
    'lineage_hpv18_fasta',
    'lineage_ref_hpv16_name',
    'lineage_ref_hpv18_name'
]

requiredParams.each { key ->
    if (!params[key]) {
        error "params.${key} is required"
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

checkPath(params.pave_ref_fasta as String, 'PAVE reference fasta')
checkPath(params.pave_gff3_dir as String, 'PAVE GFF3 directory', true)
checkPath(params.scripts_dir as String, 'Scripts directory', true)
checkPath(params.lineage_hpv16_fasta as String, 'HPV16 lineages reference FASTA')
checkPath(params.lineage_hpv18_fasta as String, 'HPV18 lineages reference FASTA')

def indexMarker = new File("${params.index_dir}/pave_hsa.1.bt2")
def indexReady = indexMarker.exists() ? Channel.value(true) : null

def bedDir = new File(params.pave_bed_dir as String)
if (bedDir.exists() && !bedDir.isDirectory()) {
    error "BED directory path is not a directory: ${params.pave_bed_dir}"
}
def bedReady = (bedDir.isDirectory() && bedDir.listFiles()?.any { it.name.endsWith('.bed') }) \
    ? Channel.value(true) \
    : null

def featuresDir = new File(params.features_tsv_dir as String)
if (featuresDir.exists() && !featuresDir.isDirectory()) {
    error "Features TSV path is not a directory: ${params.features_tsv_dir}"
}
def featuresReady = (featuresDir.isDirectory() && featuresDir.listFiles()?.any { it.name.endsWith('.tsv') }) \
    ? Channel.value(true) \
    : null

process GENERATE_FEATURES_TSV {
    tag "features_tsv"
    publishDir "${params.features_tsv_dir}", mode: 'copy'

    input:
    val(dummy)

    output:
    path "features_tsv", emit: features

    script:
    """
    mkdir -p features_tsv
    "${params.scripts_dir}/pave/gff3_to_features_tsv.run_all.sh" "${params.pave_gff3_dir}" features_tsv
    """
}

process GENERATE_BED {
    tag "bed"
    publishDir "${params.pave_bed_dir}", mode: 'copy'

    input:
    val(dummy)

    output:
    path "bed_files", emit: beds

    script:
    """
    mkdir -p bed_files
    "${params.scripts_dir}/pave/gff3_to_bed.run_all.sh" "${params.pave_gff3_dir}" bed_files
    """
}

process CREATE_INDEX {
    tag "pave_hsa"
    publishDir "${params.index_dir}", mode: 'copy', pattern: 'pave_hsa*'

    output:
    path "index/pave_hsa.1.bt2", emit: marker

    script:
    """
    mkdir -p index
    ln -sf "${params.pave_ref_fasta}" index/pave_hsa.fas
    bowtie2-build index/pave_hsa.fas index/pave_hsa
    """
}

process MAP_SAMPLE {
    tag "${run_id}:${sample_id}"
    publishDir { "${params.outdir}/${run_id}" }, mode: 'copy'

    input:
    tuple val(run_id), val(sample_id), path(read1), path(read2), val(index_ready), val(features_ready)

    output:
    tuple val(run_id), val(sample_id), path("${sample_id}.*"), emit: mapped

    script:
    """
    set -euo pipefail
    prefix="${sample_id}"

    bowtie2 --all -x "${params.index_dir}/pave_hsa" -1 "${read1}" -2 "${read2}" -S "\${prefix}.sam" -p ${task.cpus}
    samtools view -S -b "\${prefix}.sam" > "\${prefix}.u.bam"
    samtools sort "\${prefix}.u.bam" -o "\${prefix}.bam" -@ ${task.cpus}
    samtools index "\${prefix}.bam"
    samtools idxstats "\${prefix}.bam" > "\${prefix}.idxstats"

    "${params.scripts_dir}/top_strains/identify_top_strains.py" "\${prefix}.idxstats" > "\${prefix}.top_strains"

    samtools depth -aa "\${prefix}.bam" > "\${prefix}.depth"
    "${params.scripts_dir}/coverage/covstats.py" "\${prefix}.depth" "\${prefix}.depth.stats" "${params.features_tsv_dir}"

    samtools faidx "${params.index_dir}/pave_hsa.fas"
    bcftools mpileup -Ou -f "${params.index_dir}/pave_hsa.fas" "\${prefix}.bam" -d 500 | \\
      bcftools call -mv -Ob -o "\${prefix}.bcf.gz" --ploidy 1
    bcftools index "\${prefix}.bcf.gz"
    bcftools stats "\${prefix}.bcf.gz" > "\${prefix}.bcf.vchk"
    plot-vcfstats -p "\${prefix}" "\${prefix}.bcf.vchk"
    """
}

process AGGREGATE_STRAINS {
    tag "aggregate_strains"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(done)

    output:
    path "strains.tsv"

    script:
    """
    "${params.scripts_dir}/top_strains/aggregate_top_strains.sh" "${params.outdir}" "strains.tsv"
    """
}

process AGGREGATE_COVSTATS {
    tag "aggregate_covstats"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    val(done)

    output:
    path "cov_stats.tsv"
    path "cov_stats.filtered.tsv"

    script:
    """
    "${params.scripts_dir}/coverage/aggregate_covstats.py" "${params.outdir}" "cov_stats.tsv" -b 0 -d 0
    "${params.scripts_dir}/coverage/aggregate_covstats.py" "${params.outdir}" "cov_stats.filtered.tsv"
    """
}

process AGGREGATE_VARIANTS {
    tag "aggregate_variants"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    tuple val(done), val(bed_ready)

    output:
    path "E6_E7_variants.tsv"

    script:
    """
    "${params.scripts_dir}/variants/report_E6_E7_variants.sh" "${params.outdir}" "${params.pave_bed_dir}" > "E6_E7_variants.tsv"
    """
}

process AGGREGATE_VARIANT_EFFECTS {
    tag "aggregate_variant_effects"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    tuple val(done), val(bed_ready)

    output:
    path "E6_E7_variant_effects.tsv"

    script:
    """
    "${params.scripts_dir}/variants/report_E6_E7_variant_effects.sh" "${params.outdir}" "${params.pave_bed_dir}" "${params.pave_gff3_dir}" "${params.index_dir}/pave_hsa.fas" > "E6_E7_variant_effects.tsv"
    """
}

process LINEAGE_SNPS {
    tag "lineage_snps"
    publishDir "${params.reports_dir}", mode: 'copy'

    input:
    tuple val(done), val(bed_ready)

    output:
    path "lineage_snps.tsv"

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

    script:
    """
    cp "${params.reports_dir}/strains.tsv" .
    cp "${params.reports_dir}/cov_stats.tsv" .
    cp "${params.reports_dir}/cov_stats.filtered.tsv" .
    cp "${params.reports_dir}/E6_E7_variants.tsv" .
    cp "${params.reports_dir}/E6_E7_variant_effects.tsv" .
    cp "${params.reports_dir}/lineage_snp_comparison.tsv" .

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

def build_covstats_id(row, header):
    run = row[0] if len(row) > 0 else ""
    sample = row[1] if len(row) > 1 else ""
    strain = row[2] if len(row) > 2 else ""
    return f"{run}:{sample}:{strain}"

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
        reader = csv.reader(inp, delimiter='\\t')
        writer = csv.writer(out, delimiter='\\t')
        header = next(reader, None)
        if not header:
            return
        writer.writerow(['Sample'] + header)
        for row in reader:
            if not row:
                continue
            if id_builder in (build_covstats_id, build_variant_effect_id, build_variant_id) and is_undetermined(row):
                continue
            row = decode_row(row, header, decode_cols)
            if id_builder:
                sample = id_builder(row, header)
            else:
                sample = f\"{row[0]}:{row[1]}\" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)

def rewrite_no_header(src, dest, header, id_builder=None):
    if not os.path.exists(src):
        return
    with open(src, newline='') as inp, open(dest, 'w', newline='') as out:
        reader = csv.reader(inp, delimiter='\\t')
        writer = csv.writer(out, delimiter='\\t')
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
            sample = f\"{first[0]}:{first[1]}\" if len(first) > 1 else first[0]
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
                sample = f\"{row[0]}:{row[1]}\" if len(row) > 1 else row[0]
            writer.writerow([sample] + row)

rewrite_with_header('strains.tsv', 'strains.multiqc.tsv')
rewrite_with_header('cov_stats.tsv', 'cov_stats.multiqc.tsv', id_builder=build_covstats_id)
rewrite_with_header('cov_stats.filtered.tsv', 'cov_stats.filtered.multiqc.tsv', id_builder=build_covstats_id)
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
      . "${params.outdir}" "${params.reports_dir}"
    """
}

workflow {
    def multiqc_config_path = new File(params.multiqc_config)
    if (!multiqc_config_path.exists()) {
        error "MultiQC config not found: ${params.multiqc_config}"
    }

    if (!indexReady) {
        indexReady = CREATE_INDEX().marker.map { true }
    }
    if (!featuresReady) {
        featuresReady = GENERATE_FEATURES_TSV(Channel.value(true)).features.map { true }
    }
    if (!bedReady) {
        bedReady = GENERATE_BED(Channel.value(true)).beds.map { true }
    }

    def samples
    if (params.read1 && params.read2) {
        def read1 = file(params.read1 as String)
        def read2 = file(params.read2 as String)
        if (!read1.exists()) {
            error "read1 not found: ${params.read1}"
        }
        if (!read2.exists()) {
            error "read2 not found: ${params.read2}"
        }
        def runId = params.run_id ?: "run"
        def sampleId = params.sample_id ?: normalizeSampleId(read1.getName())
        samples = Channel.of(tuple(runId, sampleId, read1, read2))
    } else if (params.reads_dir) {
        def readsDir = new File(params.reads_dir as String)
        if (!readsDir.isDirectory()) {
            error "reads_dir not found: ${params.reads_dir}"
        }
        samples = Channel.fromPath("${params.reads_dir}/*/buckets/*.R1.${bucketTid}.fastq.gz")
            .map { r1 ->
                def r2 = file(r1.toString().replace('.R1.', '.R2.'))
                if (!r2.exists()) {
                    error "missing R2 for ${r1}"
                }
                def runId = r1.getParent().getParent().getFileName().toString()
                def sampleId = normalizeSampleId(r1.getFileName().toString())
                tuple(runId, sampleId, r1, r2)
            }
        if (params.run_id) {
            samples = samples.filter { runId, sampleId, r1, r2 -> runId == params.run_id }
        }
        if (params.sample_id) {
            samples = samples.filter { runId, sampleId, r1, r2 -> sampleId == params.sample_id }
        }
        samples = samples.ifEmpty { error "no matching reads found under ${params.reads_dir}" }
    } else {
        error "set either params.read1/read2 or params.reads_dir"
    }

    def samplesWithDeps = samples.combine(indexReady).combine(featuresReady)
    def mapped = MAP_SAMPLE(samplesWithDeps)
    def mappedDone = mapped.collect()
    def mappedWithBed = mappedDone.combine(bedReady)

    def strains = AGGREGATE_STRAINS(mappedDone)
    def covstats = AGGREGATE_COVSTATS(mappedDone)
    def variants = AGGREGATE_VARIANTS(mappedWithBed)
    def variant_effects = AGGREGATE_VARIANT_EFFECTS(mappedWithBed)
    def lineage_snps = LINEAGE_SNPS(mappedWithBed)
    def lineage_compare = COMPARE_LINEAGE_SNPS(variants, lineage_snps)
    def reports_done = strains.mix(covstats).mix(variants).mix(variant_effects).mix(lineage_snps).mix(lineage_compare).collect()
    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, reports_done)
}
