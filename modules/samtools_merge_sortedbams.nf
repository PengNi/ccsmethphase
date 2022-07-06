process SAMTOOLS_merge_sortedbams {
    tag "${params.dsname}.post_${params.aligner}.merged_size${num}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/bam",
        mode: "copy",
        pattern: "${params.dsname}.post_${params.aligner}.merged_size${num}.bam*",
        enabled: !params.run_clair3 || !params.run_whatshap

    input:
    path bams
    path bais

    output:
    tuple val("${params.dsname}.post_${params.aligner}.merged_size${num}"),
        path("${params.dsname}.post_${params.aligner}.merged_size${num}.bam"),
        path("${params.dsname}.post_${params.aligner}.merged_size${num}.bam.bai"),    emit: merged_bam

    script:
    cores = task.cpus
    num   = bams.size()
    """
    date; hostname; pwd

    ## WARN: when there are 2 or more bam files, bams is a list, size() returns number of items of the list
    ## WARN: but when there is only 1 bam file, bams is the bam file, size() returns the size of the file
    samtools merge -@ ${cores} ${params.dsname}.post_${params.aligner}.merged_size${num}.bam ${bams}
    samtools index -@ ${cores} ${params.dsname}.post_${params.aligner}.merged_size${num}.bam

    """

}