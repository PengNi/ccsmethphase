process DSS_callDMR {
    tag "${group_id}.${sample_id}"

    label 'process_medium'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/diff_methyl",
        mode: "copy",
        pattern: "*_callDM[LR].txt"

    publishDir "${params.outdir}/${params.dsname}/diff_methyl",
        mode: "copy",
        pattern: "*_callDMR.autosomes*.bed"

    input:
    tuple val(group_id), val(sample_id), path(beds)
    path  ch_utils

    output:
    tuple val(group_id), val(sample_id), path("*_callDML.txt"), path("*_callDMR.txt"), path("*_callDMR.autosomes*.bed"), emit: dss_dmr

    script:
    cores    = task.cpus
    bed_size = beds.size()
    """
    date; hostname; pwd

    # find the bed files used for dss
    if [[ ${bed_size} -gt 3 ]] ; then
        bed_hp1=\$(find -L ./ -type f -regex '.*.aggregate.hp1.bed')
        bed_hp2=\$(find -L ./ -type f -regex '.*.aggregate.hp2.bed')
    else
        bed_hp1=\$(find -L ./ -type f -regex '.*.hp1.bed')
        bed_hp2=\$(find -L ./ -type f -regex '.*.hp2.bed')
    fi

    echo \${bed_hp1}
    echo \${bed_hp2}

    file_prefix=\$(echo \${bed_hp1%1.bed})

    python utils/call_dmr_dss_nanomethphase.py -c 1,2,6,10,11 \
        -ca \${bed_hp1} \
        -co \${bed_hp2} \
        -o ./ \
        -op \${file_prefix} \
        --overwrite \
        > \${file_prefix}.logdmr.log

    rm \${file_prefix}_ReadyForDSS_*.tsv
    dmr_txt=\${file_prefix}_callDMR.txt
    if [[ ! -f \${dmr_txt} ]] ; then
        echo "### ERROR: no expected output file"
        exit -1
    fi
    awk 'BEGIN{ FS=OFS="\t" } NR!=1 && \$1 !~ /X/ && \$1 !~ /Y/ && \$1 !~ /_/ && \$1 !~ /M/ && sqrt(\$8 * \$8) > ${params.dmr_mdiff_cf}' \
        \${dmr_txt} \
        > \$(echo \${dmr_txt%.txt}).autosomes_cf${params.dmr_mdiff_cf}.bed
    """
}