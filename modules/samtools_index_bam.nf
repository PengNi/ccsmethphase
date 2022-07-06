process SAMTOOLS_index_bam {
    tag "${bam.baseName}"

    label 'process_medium'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    input:
    path bam

    output:
    tuple val("${bam.baseName}"), path("${bam}.bai"),    emit: bambai

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    samtools index -@ ${cores} ${bam}
    """

}
