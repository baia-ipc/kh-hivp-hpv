#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/pipelines/conda_env/pipeline.env.yml"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/pipelines/multiqc/database_snps.multiqc.yml"
params.target_country = params.target_country ?: "Cambodia"
params.selected_hpv16_fasta = params.selected_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/selected.fasta"
params.selected_hpv16_tsv = params.selected_hpv16_tsv ?: "${projectRoot}/derived_data/refdata/hpv16_tree/selected"
params.selected_hpv18_fasta = params.selected_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/selected.fasta"
params.selected_hpv18_tsv = params.selected_hpv18_tsv ?: "${projectRoot}/derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv"
params.lineage_hpv16_fasta = params.lineage_hpv16_fasta ?: "${projectRoot}/derived_data/refdata/hpv16_tree/lineages_ref_renamed.fasta"
params.lineage_hpv18_fasta = params.lineage_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/lineages_ref_renamed.fasta"
params.ref_fasta = params.ref_fasta ?: "${projectRoot}/refdata/pave/pave_hsa.fas"
params.pave_gff3_dir = params.pave_gff3_dir ?: "${projectRoot}/refdata/pave/gff3"
params.pave_bed_dir = params.pave_bed_dir ?: "${projectRoot}/derived_data/refdata/pave/bed"
params.ref_hpv16_name = params.ref_hpv16_name ?: "HPV16REF|lcl|Human"
params.ref_hpv18_name = params.ref_hpv18_name ?: "HPV18REF|lcl|Human"
params.samples_tsv = params.samples_tsv ?: "${projectRoot}/metadata/samples-input2.tsv"
// Avoid warnings for optional params
if (!params.containsKey('outdir')) params.outdir = null
if (!params.containsKey('reports_dir')) params.reports_dir = null
if (!params.containsKey('sample_variants')) params.sample_variants = null
if (!params.containsKey('sample_variant_effects')) params.sample_variant_effects = null
if (!params.containsKey('pave_gff3_dir')) params.pave_gff3_dir = null
if (!params.containsKey('pave_bed_dir')) params.pave_bed_dir = null
if (!params.containsKey('samples_tsv')) params.samples_tsv = null

[ 'outdir', 'reports_dir', 'sample_variants', 'pave_gff3_dir', 'pave_bed_dir', 'scripts_dir',
  'sample_variant_effects', 'samples_tsv', 'selected_hpv16_fasta', 'selected_hpv16_tsv',
  'selected_hpv18_fasta', 'selected_hpv18_tsv', 'lineage_hpv16_fasta', 'lineage_hpv18_fasta',
  'ref_fasta', 'ref_hpv16_name', 'ref_hpv18_name'
].each { key ->
    if (!params[key]) {
        error "params.${key} is required"
    }
}

def checkPath(String path, String label) {
    def target = new File(path)
    if (!target.exists()) {
        error "${label} not found: ${path}"
    }
}

checkPath(params.selected_hpv16_fasta, 'HPV16 selected fasta')
checkPath(params.selected_hpv16_tsv, 'HPV16 selected metadata')
checkPath(params.selected_hpv18_fasta, 'HPV18 selected fasta')
checkPath(params.selected_hpv18_tsv, 'HPV18 selected metadata')
checkPath(params.lineage_hpv16_fasta, 'HPV16 lineage fasta')
checkPath(params.lineage_hpv18_fasta, 'HPV18 lineage fasta')
checkPath(params.ref_fasta, 'PAVE reference fasta')
checkPath(params.sample_variants, 'Sample E6/E7 variants')
checkPath(params.sample_variant_effects, 'Sample E6/E7 variant effects')
checkPath(params.samples_tsv, 'Samples metadata TSV')
checkPath(params.multiqc_config, 'MultiQC config')
checkPath(params.pave_gff3_dir, 'PAVE GFF3 directory')

def bedDir = new File(params.pave_bed_dir)
if (bedDir.exists() && !bedDir.isDirectory()) {
    error "BED directory path is not a directory: ${params.pave_bed_dir}"
}
def bedReady = (bedDir.isDirectory() && bedDir.listFiles()?.any { it.name.endsWith('.bed') }) \
    ? Channel.value(true) \
    : null

process EXTRACT_DATABASE {
    tag "extract"
    publishDir "${params.outdir}", mode: 'copy'
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

process LINEAGE_SNPS {
    tag "lineage_snps"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(lineage_hpv16, stageAs: 'lineages_hpv16.fasta')
    path(lineage_hpv18, stageAs: 'lineages_hpv18.fasta')
    val(bed_ready)

    output:
    path('lineage_snps.tsv')

    script:
    """
    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${lineage_hpv16}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > lineage_snps.tsv

    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${lineage_hpv18}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv18_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      >> lineage_snps.tsv
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
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > database_snps.tsv

    "${params.scripts_dir}/variants/lineage_snps_from_fasta.py" \\
      --lineages "${database_hpv18}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv18_name}" \\
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
      --ref-fasta "${params.ref_fasta}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --output hpv16_e6e7_variants_summary.tsv
    """
}

process PREPARE_MULTIQC {
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
            reader = csv.reader(handle, delimiter='\t')
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
            writer = csv.writer(out, delimiter='\t')
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

process MULTIQC {
    tag "multiqc"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    tuple path(database_snps_table),
          path(database_lineage_table),
          path(database_sample_table),
          path(samples_vs_database_table),
          path(samples_vs_database_sets_table),
          path(samples_vs_lineage_sets_table),
          path(hpv16_e6e7_summary_table)
    path(multiqc_config)

    output:
    path('multiqc_report.html')

    script:
    """
    multiqc --force \\
      --filename "multiqc_report.html" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      .
    """
}

workflow {
    def hpv16_fasta = file(params.selected_hpv16_fasta)
    def hpv16_tsv = file(params.selected_hpv16_tsv)
    def hpv18_fasta = file(params.selected_hpv18_fasta)
    def hpv18_tsv = file(params.selected_hpv18_tsv)
    def lineage_hpv16 = file(params.lineage_hpv16_fasta)
    def lineage_hpv18 = file(params.lineage_hpv18_fasta)
    def sample_variants = file(params.sample_variants)
    def sample_variant_effects = file(params.sample_variant_effects)
    def sample_list = file(params.samples_tsv)
    def multiqc_config = file(params.multiqc_config)

    if (!bedReady) {
        bedReady = GENERATE_BED(Channel.value(true)).beds.map { true }
    }

    def database_fastas = EXTRACT_DATABASE(hpv16_fasta, hpv16_tsv, hpv18_fasta, hpv18_tsv)
    def lineage_snps = LINEAGE_SNPS(lineage_hpv16, lineage_hpv18, bedReady)
    def database_snps = DATABASE_SNPS(database_fastas, bedReady)
    def database_lineages = COMPARE_DATABASE_LINEAGES(database_snps, lineage_snps)
    def database_samples = COMPARE_DATABASE_SAMPLES(database_snps, sample_variants)
    def samples_vs_database = COMPARE_SAMPLES_DATABASE(database_snps, sample_variants)
    def compare_database_sets = file("${params.scripts_dir}/variants/compare_sample_snp_sets_to_database.py")
    def compare_lineage_sets = file("${params.scripts_dir}/variants/compare_sample_snp_sets_to_lineages.py")
    def samples_vs_database_sets = COMPARE_SNP_SETS_DATABASE(database_snps, sample_variants, compare_database_sets)
    def samples_vs_lineage_sets = COMPARE_SNP_SETS_LINEAGES(lineage_snps, sample_variants, compare_lineage_sets)
    def database_hpv16 = database_fastas.map { it[0] }
    def hpv16_summary = HPV16_E6E7_SUMMARY(sample_variant_effects, sample_list, database_snps, lineage_snps, database_hpv16, lineage_hpv16)
    def multiqc_tables = PREPARE_MULTIQC(database_snps, database_lineages, database_samples, samples_vs_database, samples_vs_database_sets, samples_vs_lineage_sets, hpv16_summary)
    MULTIQC(multiqc_tables, multiqc_config)
}
