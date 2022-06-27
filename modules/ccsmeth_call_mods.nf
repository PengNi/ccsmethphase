process CCSMETH_call_mods_denovo {
    tag "${hifi_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/mods_call",
        mode: "copy",
        pattern: "${hifi_bam.baseName}.ccsmeth.modbam.bam*",
        enabled: !params.run_align

    input:
    tuple path(hifi_bam), path(hifi_bai)
    each path(ccsmeth_cm_model)
    path ch_utils

    output:
    tuple path("${hifi_bam.baseName}.ccsmeth.modbam.bam"), path("${hifi_bam.baseName}.ccsmeth.modbam.bam.bai"),
        emit: ccsmeth_modbam

    script:
    cores = task.cpus
    gpu_cores = (params.cm_nproc_gpu).intValue()
    """
    date; hostname; pwd

    if [[ "\${CUDA_VISIBLE_DEVICES:-}" == "" || "\${CUDA_VISIBLE_DEVICES:-}" == "-1" ]] ; then
        echo "Detect no GPU, using CPU commandType"
        commandType='cpu'
    else
        echo "Detect GPU, using GPU commandType"
        commandType='gpu'
    fi

    if [[ \${commandType} == "cpu" ]]; then
        ## CPU version command
        CUDA_VISIBLE_DEVICES=-1 python utils/memusg ccsmeth call_mods --input ${hifi_bam} \
            --output ${hifi_bam.baseName}.ccsmeth \
            --model_file ${ccsmeth_cm_model} --model_type attbigru2s --seq_len 21 \
            --is_npass yes --is_qual no --is_map no --is_stds no \
            --mode denovo --threads ${cores} --threads_call ${gpu_cores} \
            > ${hifi_bam.baseName}.ccsmeth.call_mods.log 2>&1
        rm ${hifi_bam.baseName}.ccsmeth.per_readsite.tsv
    elif [[ \${commandType} == "gpu" ]]; then
        ## GPU version command
        python utils/memusg ccsmeth call_mods --input ${hifi_bam} \
            --output ${hifi_bam.baseName}.ccsmeth \
            --model_file ${ccsmeth_cm_model} --model_type attbigru2s --seq_len 21 \
            --is_npass yes --is_qual no --is_map no --is_stds no \
            --mode denovo --threads ${cores} --threads_call ${gpu_cores} \
            > ${hifi_bam.baseName}.ccsmeth.call_mods.log 2>&1
        rm ${hifi_bam.baseName}.ccsmeth.per_readsite.tsv
    else
        echo "### error value for commandType=\${commandType}"
        exit 255
    fi

    if [ ! -f ${hifi_bam.baseName}.ccsmeth.modbam.bam.bai ]; then
        samtools index -@ ${cores} ${hifi_bam.baseName}.ccsmeth.modbam.bam
    fi

    """
}