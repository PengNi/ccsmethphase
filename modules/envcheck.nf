process CheckGenome {
    tag "CheckGenome"
    errorStrategy 'terminate'

    label 'process_low'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    input:
    path reference_genome

    output:
    path "${params.genome_dir}",                   emit: reference_genome_dir, optional: true
    path "fake_output",                            emit: fake_output

    script:
    """
    date; hostname; pwd

    if [ ${params.run_align} == true ]; then
        ## Get dir for reference_genome
        find_dir="\$PWD/reference_genome_tmpdir"
        mkdir -p \${find_dir}
        if [[ ${reference_genome} == *.tar.gz && -f ${reference_genome}  ]] ; then
            tar -xzf ${reference_genome} -C \${find_dir}
        elif [[ ${reference_genome} == *.tar && -f ${reference_genome} ]] ; then
            tar -xf ${reference_genome} -C \${find_dir}
        elif [[ -d ${reference_genome} ]] ; then
            cp -r ${reference_genome}/* \${find_dir}
        elif [[ -e ${reference_genome} ]] ; then
            cp ${reference_genome} \${find_dir}/${reference_genome}.ori.fasta
        else
            echo "### ERROR: not recognized reference_genome=${reference_genome}"
            exit -1
        fi

        mkdir ${params.genome_dir}
        find \${find_dir} -name '*.fasta' | \
            parallel -j0 -v  'cat {} >> ${params.genome_dir}/${params.genome_file}'
        find \${find_dir} -name '*.fa' | \
            parallel -j0 -v  'cat {} >> ${params.genome_dir}/${params.genome_file}'
        find \${find_dir} -name '*.fna' | \
            parallel -j0 -v  'cat {} >> ${params.genome_dir}/${params.genome_file}'
        rm -r \${find_dir}

        samtools faidx ${params.genome_dir}/${params.genome_file}
    fi

    touch fake_output

    echo "referenceGenome=${params.genome_dir}/${params.genome_file}"
    echo "### Check genome DONE"
    """
}

process CheckCMModel {
    tag "CheckCMModel"
    errorStrategy 'terminate'

    label 'process_low'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    input:
    path ccsmeth_cm_model

    output:
    path "ccsmeth_call_mods_model.ckpt",           emit: ccsmeth_cm_model_ckpt, optional: true

    script:
    """
    date; hostname; pwd
    echo "CUDA_VISIBLE_DEVICES=\${CUDA_VISIBLE_DEVICES:-}"

    ## ccsmeth call_mods model
    if [ ${params.run_call_mods} == true ]; then
        if [ ${ccsmeth_cm_model} == null2 ] ; then
            echo "### INFO: gonna use the default ccsmeth_cm_model=${params.DEFAULT_CCSMETH_CM_MODEL}"
        elif [[ ${ccsmeth_cm_model} != *.ckpt && ${ccsmeth_cm_model} != *.checkpoint ]]; then
            echo "### ERROR: not recognized ccsmeth_cm_model=${ccsmeth_cm_model}"
            exit -1
        fi
        cp -a ${ccsmeth_cm_model} ccsmeth_call_mods_model.ckpt
        ls -lh ccsmeth_call_mods_model.ckpt
    fi

    echo "### Check cm_model DONE"
    """
}

process CheckAGModel {
    tag "CheckAGModel"
    errorStrategy 'terminate'

    label 'process_low'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    input:
    path ccsmeth_ag_model

    output:
    path "ccsmeth_aggregate_model.ckpt",           emit: ccsmeth_ag_model_ckpt, optional: true

    script:
    """
    date; hostname; pwd

    ## ccsmeth aggregate model
    if [[ ${params.run_call_mods} == true && ${params.run_call_freq} == true ]]; then
        if [ "${params.cf_mode}" != "aggregate" ]; then
            echo "### INFO: params.cf_mode != aggregate"
        elif [ ${ccsmeth_ag_model} == null3 ] ; then
            echo "### INFO: gonna use the default ccsmeth_ag_model=${params.DEFAULT_CCSMETH_AG_MODEL}"
        elif [[ ${ccsmeth_ag_model} != *.ckpt && ${ccsmeth_ag_model} != *.checkpoint ]]; then
            echo "### ERROR: not recognized ccsmeth_ag_model=${ccsmeth_ag_model}"
            exit -1
        fi
        cp -a ${ccsmeth_ag_model} ccsmeth_aggregate_model.ckpt
        ls -lh ccsmeth_aggregate_model.ckpt
    fi

    echo "### Check ag_model DONE"
    """
}
