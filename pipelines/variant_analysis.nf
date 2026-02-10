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
params.analysis_name = params.analysis_name ?: null
params.step_name = params.step_name ?: "03.variant_analysis"
params.input_step_name = params.input_step_name ?: "02.mapping_vs_pave"
def outdirParam = params.containsKey('outdir') ? params.outdir : null
def reportsDirParam = params.containsKey('reports_dir') ? params.reports_dir : null
def multiqcOutdirParam = params.containsKey('multiqc_outdir') ? params.multiqc_outdir : null
def multiqcReportNameParam = params.containsKey('multiqc_report_name') ? params.multiqc_report_name : null
def mappingOutdirParam = params.containsKey('mapping_outdir') ? params.mapping_outdir : null
def databaseOutdirParam = params.containsKey('database_outdir') ? params.database_outdir : null

if (!outdirParam && params.analysis_name && params.step_name) {
    outdirParam = "${projectRoot}/outs/${params.analysis_name}/${params.step_name}"
}
if (!reportsDirParam && outdirParam) {
    reportsDirParam = "${outdirParam}/reports"
}
if (!multiqcReportNameParam) {
    multiqcReportNameParam = params.step_name \
        ? params.step_name.replace('.', '_') + ".report.html" \
        : "multiqc_report.html"
}
if ((!multiqcOutdirParam || multiqcOutdirParam.contains('unknown_analysis')) && params.analysis_name) {
    multiqcOutdirParam = "${projectRoot}/results/reports/${params.analysis_name}"
} else if (!multiqcOutdirParam) {
    multiqcOutdirParam = reportsDirParam
}
if (!mappingOutdirParam && params.analysis_name && params.input_step_name) {
    mappingOutdirParam = "${projectRoot}/outs/${params.analysis_name}/${params.input_step_name}"
}

if (!databaseOutdirParam && outdirParam) {
    databaseOutdirParam = "${outdirParam}/database_snps"
}

params.outdir = outdirParam
params.reports_dir = reportsDirParam
params.multiqc_outdir = multiqcOutdirParam
params.multiqc_report_name = multiqcReportNameParam
params.mapping_outdir = mappingOutdirParam
params.database_outdir = databaseOutdirParam
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
params.selected_hpv16_tsv = params.selected_hpv16_tsv ?: "${projectRoot}/derived_data/refdata/hpv16_tree/HPV16-NCBIVirus.selected.tsv"
params.selected_hpv18_fasta = params.selected_hpv18_fasta ?: "${projectRoot}/derived_data/refdata/hpv18_tree/selected.fasta"
params.selected_hpv18_tsv = params.selected_hpv18_tsv ?: "${projectRoot}/derived_data/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv"

if (!params.containsKey('samples_tsv')) params.samples_tsv = null

[ 'mapping_outdir', 'reports_dir', 'scripts_dir', 'pave_bed_dir', 'pave_gff3_dir',
    'bowtie_index_dir', 'pave_ref_fasta'
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
    publishDir { "${params.pave_bed_dir}" }, mode: 'copy'

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
    publishDir { "${params.database_outdir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    publishDir { "${params.reports_dir}" }, mode: 'copy'
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
    python "${params.scripts_dir}/variants/prepare_database_multiqc_tables.py" \
      --database-snps "database_snps.tsv" --database-snps-out "database_snps.multiqc.tsv" \
      --database-lineage-comparison "database_lineage_comparison.tsv" --database-lineage-comparison-out "database_lineage_comparison.multiqc.tsv" \
      --database-sample-comparison "database_sample_comparison.tsv" --database-sample-comparison-out "database_sample_comparison.multiqc.tsv" \
      --samples-vs-database "samples_vs_database.tsv" --samples-vs-database-out "samples_vs_database.multiqc.tsv" \
      --samples-vs-database-sets "samples_vs_database_sets.tsv" --samples-vs-database-sets-out "samples_vs_database_sets.multiqc.tsv" \
      --samples-vs-lineage-sets "samples_vs_lineage_sets.tsv" --samples-vs-lineage-sets-out "samples_vs_lineage_sets.multiqc.tsv" \
      --hpv16-e6e7-summary "hpv16_e6e7_variants_summary.tsv" --hpv16-e6e7-summary-out "hpv16_e6e7_variants_summary.multiqc.tsv"
    """
}

process AGGREGATE_VARIANTS {
    tag "aggregate_variants"
    publishDir { "${params.reports_dir}" }, mode: 'copy'

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
    publishDir { "${params.reports_dir}" }, mode: 'copy'

    input:
    val(bed_ready)

    output:
    path "E6_E7_variant_effects.tsv"

    script:
    """
    "${params.scripts_dir}/variants/report_E6_E7_variant_effects.sh" "${params.mapping_outdir}" "${params.pave_bed_dir}" "${params.pave_gff3_dir}" "${params.bowtie_index_dir}/pave_hsa.fas" > "E6_E7_variant_effects.tsv"
    """
}

process LINEAGE_SNPS {
    tag "lineage_snps"
    publishDir { "${params.reports_dir}" }, mode: 'copy'

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
    publishDir { "${params.reports_dir}" }, mode: 'copy'

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
    publishDir { "${params.multiqc_outdir}" }, mode: 'copy', pattern: "${params.multiqc_report_name}"

    input:
    path(multiqc_config)
    path(done)

    output:
    path("${params.multiqc_report_name}")

    script:
    """
    cp "${params.reports_dir}/E6_E7_variants.tsv" .
    cp "${params.reports_dir}/E6_E7_variant_effects.tsv" .
    if [ -f "${params.reports_dir}/lineage_snp_comparison.tsv" ]; then
      cp "${params.reports_dir}/lineage_snp_comparison.tsv" .
    fi

    python "${params.scripts_dir}/variants/prepare_variant_multiqc_inputs.py" \
      --variants "E6_E7_variants.tsv" --variants-out "E6_E7_variants.multiqc.tsv" \
      --variant-effects "E6_E7_variant_effects.tsv" --variant-effects-out "E6_E7_variant_effects.multiqc.tsv" \
      --lineage-compare "lineage_snp_comparison.tsv" --lineage-compare-out "lineage_snp_comparison.multiqc.tsv"

    cp "E6_E7_variants.multiqc.tsv" "${params.reports_dir}/"
    cp "E6_E7_variant_effects.multiqc.tsv" "${params.reports_dir}/"
    if [ -f "lineage_snp_comparison.multiqc.tsv" ]; then
      cp "lineage_snp_comparison.multiqc.tsv" "${params.reports_dir}/"
    fi

    multiqc --force \\
      --filename "${params.multiqc_report_name}" \\
      --config "${multiqc_config}" \\
      --outdir . \\
      . "${params.reports_dir}"

    python "${params.scripts_dir}/variants/reorder_multiqc_sections.py" \\
      --report "${params.multiqc_report_name}" \\
      --section-id "general_stats" \\
      --section-id "mqc-module-section-bcftools" \\
      --section-id "mqc-module-section-Samtools" \\
      --nav-anchor "general_stats" \\
      --nav-anchor "bcftools" \\
      --nav-anchor "Samtools"
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

    // Re-include mapping QC outputs so samtools/bcftools modules are reported in this step's MultiQC.
    def mapping_idxstats = Channel.fromPath("${params.mapping_outdir}/*/*.idxstats", checkIfExists: false)
    def mapping_bcftools = Channel.fromPath("${params.mapping_outdir}/*/*.bcf.vchk", checkIfExists: false)
    reports_done = reports_done.mix(mapping_idxstats, mapping_bcftools)

    reports_done = reports_done.collect()

    def multiqc_config_file = file(params.multiqc_config)
    MULTIQC(multiqc_config_file, reports_done)
}
