#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.nio.file.Paths

def projectRoot = (workflow.projectDir instanceof java.nio.file.Path \
    ? workflow.projectDir \
    : Paths.get(workflow.projectDir.toString())) \
    .resolve('..').normalize().toString()

params.scripts_dir = params.scripts_dir ?: "${projectRoot}/scripts"
params.conda_env = params.conda_env ?: "${projectRoot}/config/bowtie_vs_pave.env.yml"
params.multiqc_config = params.multiqc_config ?: "${projectRoot}/config/cambodia_snps.multiqc.yml"
params.target_country = params.target_country ?: "Cambodia"
params.selected_hpv16_fasta = params.selected_hpv16_fasta ?: "${projectRoot}/refdata/hpv16_tree/selected.fasta"
params.selected_hpv16_tsv = params.selected_hpv16_tsv ?: "${projectRoot}/refdata/hpv16_tree/selected"
params.selected_hpv18_fasta = params.selected_hpv18_fasta ?: "${projectRoot}/refdata/hpv18_tree/selected.fasta"
params.selected_hpv18_tsv = params.selected_hpv18_tsv ?: "${projectRoot}/refdata/hpv18_tree/HPV18-NCBIVirus.acc_country.selected.tsv"
params.lineage_hpv16_fasta = params.lineage_hpv16_fasta ?: "${projectRoot}/refdata/hpv16_tree/lineages_ref_renamed.fasta"
params.lineage_hpv18_fasta = params.lineage_hpv18_fasta ?: "${projectRoot}/refdata/hpv18_tree/lineages_ref_renamed.fasta"
params.ref_fasta = params.ref_fasta ?: "${projectRoot}/refdata/pave/pave_hsa.fas"
params.ref_hpv16_name = params.ref_hpv16_name ?: "HPV16REF|lcl|Human"
params.ref_hpv18_name = params.ref_hpv18_name ?: "HPV18REF|lcl|Human"

// Avoid warnings for optional params
if (!params.containsKey('outdir')) params.outdir = null
if (!params.containsKey('reports_dir')) params.reports_dir = null
if (!params.containsKey('sample_variants')) params.sample_variants = null
if (!params.containsKey('pave_bed_dir')) params.pave_bed_dir = null

[ 'outdir', 'reports_dir', 'sample_variants', 'pave_bed_dir', 'scripts_dir',
  'selected_hpv16_fasta', 'selected_hpv16_tsv', 'selected_hpv18_fasta', 'selected_hpv18_tsv',
  'lineage_hpv16_fasta', 'lineage_hpv18_fasta', 'ref_fasta', 'ref_hpv16_name', 'ref_hpv18_name'
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
checkPath(params.multiqc_config, 'MultiQC config')
checkPath(params.pave_bed_dir, 'PAVE BED directory')

process EXTRACT_CAMBODIA {
    tag "extract"
    publishDir "${params.outdir}", mode: 'copy'
    conda params.conda_env

    input:
    path(hpv16_fasta, stageAs: 'hpv16_selected.fasta')
    path(hpv16_tsv, stageAs: 'hpv16_selected.tsv')
    path(hpv18_fasta, stageAs: 'hpv18_selected.fasta')
    path(hpv18_tsv, stageAs: 'hpv18_selected.tsv')

    output:
    tuple path('cambodia_hpv16.fasta'), path('cambodia_hpv18.fasta')

    script:
    """
    "${params.scripts_dir}/extract_country_sequences.py" \\
      --selected-fasta "${hpv16_fasta}" \\
      --selected-metadata "${hpv16_tsv}" \\
      --country "${params.target_country}" \\
      --label-prefix "HPV16" \\
      --output cambodia_hpv16.fasta

    "${params.scripts_dir}/extract_country_sequences.py" \\
      --selected-fasta "${hpv18_fasta}" \\
      --selected-metadata "${hpv18_tsv}" \\
      --country "${params.target_country}" \\
      --label-prefix "HPV18" \\
      --output cambodia_hpv18.fasta
    """
}

process LINEAGE_SNPS {
    tag "lineage_snps"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(lineage_hpv16, stageAs: 'lineages_hpv16.fasta')
    path(lineage_hpv18, stageAs: 'lineages_hpv18.fasta')

    output:
    path('lineage_snps.tsv')

    script:
    """
    "${params.scripts_dir}/lineage_snps_from_fasta.py" \\
      --lineages "${lineage_hpv16}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > lineage_snps.tsv

    "${params.scripts_dir}/lineage_snps_from_fasta.py" \\
      --lineages "${lineage_hpv18}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv18_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      >> lineage_snps.tsv
    """
}

process CAMBODIA_SNPS {
    tag "cambodia_snps"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    tuple path(cambodia_hpv16), path(cambodia_hpv18)

    output:
    path('cambodia_snps.tsv')

    script:
    """
    "${params.scripts_dir}/lineage_snps_from_fasta.py" \\
      --lineages "${cambodia_hpv16}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv16_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      --header > cambodia_snps.tsv

    "${params.scripts_dir}/lineage_snps_from_fasta.py" \\
      --lineages "${cambodia_hpv18}" \\
      --ref "${params.ref_fasta}" \\
      --ref-name "${params.ref_hpv18_name}" \\
      --bed-dir "${params.pave_bed_dir}" \\
      >> cambodia_snps.tsv
    """
}

process COMPARE_CAMBODIA_LINEAGES {
    tag "cambodia_vs_lineages"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(cambodia_snps)
    path(lineage_snps)

    output:
    path('cambodia_lineage_comparison.tsv')

    script:
    """
    "${params.scripts_dir}/compare_query_snps_to_lineages.py" \\
      --query-snps "${cambodia_snps}" \\
      --lineage-snps "${lineage_snps}" \\
      --output cambodia_lineage_comparison.tsv
    """
}

process COMPARE_CAMBODIA_SAMPLES {
    tag "cambodia_vs_samples"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(cambodia_snps)
    path(sample_variants)

    output:
    path('cambodia_sample_comparison.tsv')

    script:
    """
    "${params.scripts_dir}/compare_query_snps_to_samples.py" \\
      --query-snps "${cambodia_snps}" \\
      --variants "${sample_variants}" \\
      --output cambodia_sample_comparison.tsv
    """
}

process COMPARE_SAMPLES_CAMBODIA {
    tag "samples_vs_cambodia"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(cambodia_snps)
    path(sample_variants)

    output:
    path('samples_vs_cambodia.tsv')

    script:
    """
    "${params.scripts_dir}/compare_samples_to_query_snps.py" \\
      --variants "${sample_variants}" \\
      --query-snps "${cambodia_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_cambodia.tsv
    """
}

process COMPARE_SNP_SETS_CAMBODIA {
    tag "samples_vs_cambodia_sets"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(cambodia_snps)
    path(sample_variants)

    output:
    path('samples_vs_cambodia_sets.tsv')

    script:
    """
    "${params.scripts_dir}/compare_sample_snp_sets_to_cambodia.py" \\
      --variants "${sample_variants}" \\
      --cambodia-snps "${cambodia_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_cambodia_sets.tsv
    """
}

process COMPARE_SNP_SETS_LINEAGES {
    tag "samples_vs_lineage_sets"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(lineage_snps)
    path(sample_variants)

    output:
    path('samples_vs_lineage_sets.tsv')

    script:
    """
    "${params.scripts_dir}/compare_sample_snp_sets_to_lineages.py" \\
      --variants "${sample_variants}" \\
      --lineage-snps "${lineage_snps}" \\
      --allow-strains "HPV16REF,HPV18REF" \\
      --output samples_vs_lineage_sets.tsv
    """
}

process PREPARE_MULTIQC {
    tag "multiqc_tables"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    path(cambodia_snps)
    path(cambodia_lineage_comparison)
    path(cambodia_sample_comparison)
    path(samples_vs_cambodia)
    path(samples_vs_cambodia_sets)
    path(samples_vs_lineage_sets)

    output:
    tuple path('cambodia_snps.multiqc.tsv'),
          path('cambodia_lineage_comparison.multiqc.tsv'),
          path('cambodia_sample_comparison.multiqc.tsv'),
          path('samples_vs_cambodia.multiqc.tsv'),
          path('samples_vs_cambodia_sets.multiqc.tsv'),
          path('samples_vs_lineage_sets.multiqc.tsv')

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
                writer.writerow(['ID', 'cambodia_id', 'gene', 'chrom', 'pos', 'ref', 'alt'])
            return
        header = rows[0]
        start_idx = 1 if header and header[0] in ('lineage', 'cambodia_id', 'query_id', 'sample') else 0
        if start_idx == 0:
            header = ['cambodia_id', 'gene', 'chrom', 'pos', 'ref', 'alt'] + header[6:]
        else:
            header = header[:]
            if header[0] in ('lineage', 'query_id', 'sample'):
                header[0] = 'cambodia_id'
        with open(output_path, 'w', newline='') as out:
            writer = csv.writer(out, delimiter='\t')
            writer.writerow(['ID'] + header)
            for row in rows[start_idx:]:
                if len(row) < 6:
                    continue
                cambodia_id, gene, chrom, pos, ref, alt = row[:6]
                extra = row[6:]
                row_id = id_builder(cambodia_id, gene, pos, ref, alt)
                writer.writerow([row_id, cambodia_id, gene, chrom, pos, ref, alt] + extra)

    def build_id(cambodia_id, gene, pos, ref, alt):
        return f"{cambodia_id}:{gene}:{ref}{pos}{alt}"

    prepare('cambodia_snps.tsv', 'cambodia_snps.multiqc.tsv', build_id)
    prepare('cambodia_lineage_comparison.tsv', 'cambodia_lineage_comparison.multiqc.tsv', build_id)
    prepare('cambodia_sample_comparison.tsv', 'cambodia_sample_comparison.multiqc.tsv', build_id)
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

    prepare_samples('samples_vs_cambodia.tsv', 'samples_vs_cambodia.multiqc.tsv')

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

    prepare_set_comparison('samples_vs_cambodia_sets.tsv', 'samples_vs_cambodia_sets.multiqc.tsv', 'cambodia_id')
    prepare_set_comparison('samples_vs_lineage_sets.tsv', 'samples_vs_lineage_sets.multiqc.tsv', 'lineage')
    PY
    """
}

process MULTIQC {
    tag "multiqc"
    publishDir "${params.reports_dir}", mode: 'copy'
    conda params.conda_env

    input:
    tuple path(cambodia_snps_table),
          path(cambodia_lineage_table),
          path(cambodia_sample_table),
          path(samples_vs_cambodia_table),
          path(samples_vs_cambodia_sets_table),
          path(samples_vs_lineage_sets_table)
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
    def multiqc_config = file(params.multiqc_config)

    def cambodia_fastas = EXTRACT_CAMBODIA(hpv16_fasta, hpv16_tsv, hpv18_fasta, hpv18_tsv)
    def lineage_snps = LINEAGE_SNPS(lineage_hpv16, lineage_hpv18)
    def cambodia_snps = CAMBODIA_SNPS(cambodia_fastas)
    def cambodia_lineages = COMPARE_CAMBODIA_LINEAGES(cambodia_snps, lineage_snps)
    def cambodia_samples = COMPARE_CAMBODIA_SAMPLES(cambodia_snps, sample_variants)
    def samples_vs_cambodia = COMPARE_SAMPLES_CAMBODIA(cambodia_snps, sample_variants)
    def samples_vs_cambodia_sets = COMPARE_SNP_SETS_CAMBODIA(cambodia_snps, sample_variants)
    def samples_vs_lineage_sets = COMPARE_SNP_SETS_LINEAGES(lineage_snps, sample_variants)
    def multiqc_tables = PREPARE_MULTIQC(cambodia_snps, cambodia_lineages, cambodia_samples, samples_vs_cambodia, samples_vs_cambodia_sets, samples_vs_lineage_sets)
    MULTIQC(multiqc_tables, multiqc_config)
}
