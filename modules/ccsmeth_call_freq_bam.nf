process CCSMETH_call_freq_bam {
    tag "${phased_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/mods_call",
        mode: "copy",
        pattern: "*bed"

    input:
    tuple val(bam_id), path(phased_bam), path(phased_bai)
    each path(genome_dir)
    path ch_utils

    output:
    tuple val(bam_id),
        path("*bed"),
        emit: ccsmeth_haped_bed

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    ## TODO: add --aggregate_model when cf_mode == aggregate
    python utils/memusg ccsmeth call_freqb --input_bam ${phased_bam} \
        --ref ${genome_dir}/${params.genome_file} \
        --output ${phased_bam.baseName}.freq \
        --bed --sort --threads ${cores} \
        --call_mode ${params.cf_mode} \
        > ${phased_bam.baseName}.freq.call_freqb.log 2>&1
    """
}
