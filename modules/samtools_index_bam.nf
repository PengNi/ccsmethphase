process SAMTOOLS_index_bam {
    tag "${bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    input:
    tuple val(group_id), val(sample_id), path(bam)

    output:
    tuple val(group_id), val(sample_id), path(bam), path("${bam}.bai"),    emit: bambai

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    samtools index -@ ${cores} ${bam}
    """

}
