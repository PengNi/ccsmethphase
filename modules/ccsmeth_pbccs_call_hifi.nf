process CCSMETH_pbccs_call_hifi {
    tag "${subreads_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/bam",
        mode: "copy",
        pattern: "${subreads_bam.baseName}.hifi.bam*"

    input:
    path subreads_bam
    path ch_utils

    output:
    tuple path("${subreads_bam.baseName}.hifi.bam"), path("${subreads_bam.baseName}.hifi.bam.bai"),
        emit: hifi_bambai

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    python utils/memusg ccsmeth call_hifi --subreads ${subreads_bam} \
        --threads ${cores} \
        --output ${subreads_bam.baseName}.hifi.bam \
        --log-level INFO > ${subreads_bam.baseName}.hifi.call_hifi.log 2>&1
    """
}