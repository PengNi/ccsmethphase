process SAMTOOLS_merge_sortedbams {
    tag "${group_id}.${sample_id}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/bam",
        mode: "copy",
        pattern: "${group_id}.${sample_id}.*.bam*",
        enabled: !params.run_clair3 || !params.run_whatshap

    input:
    tuple val(group_id), val(sample_id), path(bams), path(bais)

    output:
    tuple val(group_id), val(sample_id),
        path("${group_id}.${sample_id}.*.bam"),
        path("${group_id}.${sample_id}.*.bam.bai"),    emit: merged_bam

    script:
    cores = task.cpus
    num   = bams.size()
    """
    date; hostname; pwd

    ## WARN: when there are 2 or more bam files, bams is a list, size() returns number of items of the list
    ## WARN: but when there is only 1 bam file, bams is the bam file, size() returns the size of the file
    if [[ ${num} -gt 2000 ]] ; then
        msize=1
    else
        msize=${num}
    fi
    if [[ ${params.run_call_mods} == true ]]; then
        name_prefix="${group_id}.${sample_id}.hifi.ccsmeth.modbam.${params.aligner}.merged_size\${msize}"
    else
        name_prefix="${group_id}.${sample_id}.hifi.${params.aligner}.merged_size\${msize}"
    fi
    samtools merge -@ ${cores} \${name_prefix}.bam ${bams}
    samtools index -@ ${cores} \${name_prefix}.bam

    """
}
