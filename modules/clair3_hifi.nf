process CLAIR3_hifi {
    tag "${align_bam.baseName}"

    label 'process_high'

    conda     (params.enable_conda ? "${projectDir}/environment-clair3.yml" : null)
    container (params.use_docker ? "${params.clair3_docker_name}" : "${params.clair3_singularity_name}")

    publishDir "${params.outdir}/${params.dsname}/vcf",
        mode: "copy",
        pattern: "*.vcf*"

    input:
    tuple val(bam_id), path(align_bam), path(align_bai)
    each path(genome_dir)

    output:
    tuple val(bam_id),
        path("${align_bam.baseName}.clair3_merge.vcf.gz"),
        path("${align_bam.baseName}.clair3_merge.vcf.gz.tbi"), emit: clair3_vcf

    script:
    cores = task.cpus
    """
    date; hostname; pwd

    clair3_out="clair3_out_${align_bam.baseName}"
    /opt/bin/run_clair3.sh \
        --bam_fn=${align_bam} \
        --ref_fn=${genome_dir}/${params.genome_file} \
        --threads=${cores} \
        --platform="hifi" \
        --model_path="${params.clair3_hifi_model}" \
        --output=\${clair3_out} \
        ${params.include_all_ctgs ? "--include_all_ctgs" : ""} \
        > \${clair3_out}.log 2>&1

    if [[ -f \${clair3_out}/merge_output.vcf.gz ]]; then
        cp \${clair3_out}/merge_output.vcf.gz ${align_bam.baseName}.clair3_merge.vcf.gz
        cp \${clair3_out}/merge_output.vcf.gz.tbi ${align_bam.baseName}.clair3_merge.vcf.gz.tbi
    else
        ##echo "### no output of clair3_hifi"
        ##exit 255
        touch ${align_bam.baseName}.clair3_merge.vcf.gz
        touch ${align_bam.baseName}.clair3_merge.vcf.gz.tbi
    fi

    rm -r \${clair3_out}
    """
}
