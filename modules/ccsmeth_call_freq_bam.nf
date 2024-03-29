process CCSMETH_call_freq_bam {
    tag "${phased_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/mods_freq",
        mode: "copy",
        pattern: "*bed"

    input:
    tuple val(group_id), val(sample_id), path(phased_bam), path(phased_bai)
    each path(genome_dir)
    each path(ccsmeth_ag_model)
    path ch_utils

    output:
    tuple val(group_id), val(sample_id),
        path("*bed"),
        emit: ccsmeth_haped_bed

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    if [[ "${params.cf_mode}" == "aggregate" ]] ; then
        if [[ "${params.ccsmeth_ag_model}" == "${params.DEFAULT_CCSMETH_AG_MODEL}" ]] ; then
            model_file="${params.DEFAULT_CCSMETH_AG_MODEL}"
        else
            model_file="${ccsmeth_ag_model}"
        fi
    fi

    python utils/memusg ccsmeth call_freqb --input_bam ${phased_bam} \
        --ref ${genome_dir}/${params.genome_file} \
        --output ${phased_bam.baseName}.freq \
        --bed --sort --threads ${cores} \
        --call_mode ${params.cf_mode} ${params.cf_mode=='aggregate' ? '--aggre_model \${model_file}' : ''} \
        ${params.cf_bonus_options!='' && params.cf_bonus_options!=true ? params.cf_bonus_options : ''} \
        > ${phased_bam.baseName}.freq.call_freqb.log 2>&1

    if [[ "${params.cf_mode}" == "aggregate" && ${params.cf_always_count} == true ]] ; then
        python utils/memusg ccsmeth call_freqb --input_bam ${phased_bam} \
        --ref ${genome_dir}/${params.genome_file} \
        --output ${phased_bam.baseName}.freq \
        --bed --sort --threads ${cores} \
        --call_mode count \
        ${params.cf_bonus_options!='' && params.cf_bonus_options!=true ? params.cf_bonus_options : ''} \
        > ${phased_bam.baseName}.freq.call_freqb_count.log 2>&1
    fi
    """
}
