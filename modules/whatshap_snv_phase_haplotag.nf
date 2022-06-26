process WHATSHAP_snv_phase_haplotag {
    tag "${bam_id}"

    label 'process_medium'

    conda     (params.enable_conda ? "${projectDir}/environment.yml" : null)
    container (params.use_docker ? "${params.docker_name}" : "${params.singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/whatshap",
        mode: "copy",
        pattern: "*{vcf,bam}*"

    input:
    tuple val(bam_id), path(clair3_vcf), path(clair3_vcf_tbi), path(input_bam), path(input_bai)
    each path(genome_dir)

    output:
    tuple val(bam_id),
        path("${clair3_vcf.baseName}.SNV_whatshap.vcf.gz"),
        path("${clair3_vcf.baseName}.SNV_whatshap.vcf.gz.tbi"),
        path("${input_bam.baseName}.SNV_whatshap.bam"),
        path("${input_bam.baseName}.SNV_whatshap.bam.bai"),
        emit: phased_vcf_bam

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    gunzip -c ${clair3_vcf} | \
        awk '/^#/ || (\$4 != "." && \$5 != "." && length(\$4) == 1 && length(\$5) == 1 && \$7 =="PASS")' \
        - > ${clair3_vcf.baseName}.SNV_PASS.vcf
    whatshap phase --ignore-read-groups --reference ${genome_dir}/${params.genome_file} \
        -o ${clair3_vcf.baseName}.SNV_whatshap.vcf \
        ${clair3_vcf.baseName}.SNV_PASS.vcf ${input_bam} \
        > ${clair3_vcf.baseName}.SNV_whatshap.whatshap_phased.log 2>&1
    bgzip -@ ${cores} ${clair3_vcf.baseName}.SNV_whatshap.vcf && \
        tabix -p vcf ${clair3_vcf.baseName}.SNV_whatshap.vcf.gz
    whatshap haplotag --ignore-read-groups \
        --output-haplotag-list ${input_bam.baseName}.SNV_whatshap.bam.readlist \
        -o ${input_bam.baseName}.SNV_whatshap.bam \
        --reference ${genome_dir}/${params.genome_file} \
        ${clair3_vcf.baseName}.SNV_whatshap.vcf.gz \
        ${input_bam} > ${input_bam.baseName}.SNV_whatshap.whatshap_haplotag.log 2>&1
    samtools index -@ ${cores} ${input_bam.baseName}.SNV_whatshap.bam
    """
}