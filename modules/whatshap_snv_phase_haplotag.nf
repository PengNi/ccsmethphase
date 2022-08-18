process WHATSHAP_snv_phase_haplotag {
    tag "${group_id}.${sample_id}"

    label 'process_medium'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/bam",
        mode: "copy",
        pattern: "*.bam*"

    publishDir "${params.outdir}/${params.dsname}/vcf/whatshap_phased",
        mode: "copy",
        pattern: "*.vcf*"

    input:
    tuple val(group_id), val(sample_id), path(clair3_vcf), path(clair3_vcf_tbi), path(input_bam), path(input_bai)
    each path(genome_dir)

    output:
    tuple val(group_id), val(sample_id),
        path("*.SNV_PASS_whatshap.vcf.gz"),
        path("*.SNV_PASS_whatshap.vcf.gz.tbi"),
        path("${input_bam.baseName}.SNV_PASS_whatshap.bam"),
        path("${input_bam.baseName}.SNV_PASS_whatshap.bam.bai"),
        emit: phased_vcf_bam

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    vcf_prefix=${clair3_vcf}
    if [[ ${clair3_vcf} == *.vcf.gz ]]; then
        vcf_prefix=\${vcf_prefix%.vcf.gz}
    elif [[ ${clair3_vcf} == *.vcf ]]; then
        vcf_prefix=\${vcf_prefix%.vcf}
    fi
    ## echo \${vcf_prefix}

    gunzip -c ${clair3_vcf} | \
        awk '/^#/ || (\$4 != "." && \$5 != "." && length(\$4) == 1 && length(\$5) == 1 && \$7 =="PASS")' \
        - > \${vcf_prefix}.SNV_PASS.vcf
    whatshap phase --ignore-read-groups --reference ${genome_dir}/${params.genome_file} \
        -o \${vcf_prefix}.SNV_PASS_whatshap.vcf \
        \${vcf_prefix}.SNV_PASS.vcf ${input_bam} \
        > \${vcf_prefix}.SNV_PASS_whatshap.whatshap_phased.log 2>&1
    rm \${vcf_prefix}.SNV_PASS.vcf
    bgzip -@ ${cores} \${vcf_prefix}.SNV_PASS_whatshap.vcf && \
        tabix -p vcf \${vcf_prefix}.SNV_PASS_whatshap.vcf.gz
    whatshap haplotag --ignore-read-groups \
        --output-haplotag-list ${input_bam.baseName}.SNV_PASS_whatshap.bam.readlist \
        -o ${input_bam.baseName}.SNV_PASS_whatshap.bam \
        --reference ${genome_dir}/${params.genome_file} \
        \${vcf_prefix}.SNV_PASS_whatshap.vcf.gz \
        ${input_bam} > ${input_bam.baseName}.SNV_PASS_whatshap.whatshap_haplotag.log 2>&1
    samtools index -@ ${cores} ${input_bam.baseName}.SNV_PASS_whatshap.bam
    """
}
