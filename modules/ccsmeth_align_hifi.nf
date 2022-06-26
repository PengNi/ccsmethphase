process CCSMETH_align_hifi {
    tag "${to_map_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/align",
        mode: "copy",
        pattern: "${to_map_bam.baseName}.${params.aligner}.bam*",
        enabled: !params.run_whatshap

    input:
    tuple path(to_map_bam), path(to_map_bai)
    each path(genome_dir)
    path ch_utils

    output:
    tuple val("${to_map_bam.baseName}.${params.aligner}"),
        path("${to_map_bam.baseName}.${params.aligner}.bam"),
        path("${to_map_bam.baseName}.${params.aligner}.bam.bai"),
        emit: align_bam

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    if [[ "${params.aligner}" == "pbmm2" ]]; then
        python utils/memusg ccsmeth align_hifi \
            --hifireads ${to_map_bam} \
            --ref ${genome_dir}/${params.genome_file} \
            --output ${to_map_bam.baseName}.${params.aligner}.bam \
            --threads ${cores} \
            > ${to_map_bam.baseName}.ccsmeth.align.log 2>&1
    elif [[ "${params.aligner}" == "minimap2" ]]; then
        python utils/memusg ccsmeth align_hifi \
            --hifireads ${to_map_bam} \
            --ref ${genome_dir}/${params.genome_file} \
            --output ${to_map_bam.baseName}.${params.aligner}.bam \
            --threads ${cores} \
            --minimap2 \
            > ${to_map_bam.baseName}.ccsmeth.align.log 2>&1
    elif [[ "${params.aligner}" == "bwa" ]]; then
        python utils/memusg ccsmeth align_hifi \
            --hifireads ${to_map_bam} \
            --ref ${genome_dir}/${params.genome_file} \
            --output ${to_map_bam.baseName}.${params.aligner}.bam \
            --threads ${cores} \
            --bwa \
            > ${to_map_bam.baseName}.ccsmeth.align.log 2>&1
    else
        echo "### error value for aligner=${params.aligner}"
        exit 255
    fi

    if [ ! -f ${to_map_bam.baseName}.${params.aligner}.bam.bai ]; then
        samtools index -@ ${cores} ${to_map_bam.baseName}.${params.aligner}.bam
    fi

    """
}