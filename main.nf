#!/usr/bin/env nextflow
/*
========================================================================================
    ccsmethphase
========================================================================================
    Github : https://github.com/PengNi/ccsmethphase
----------------------------------------------------------------------------------------
*/

if( nextflow.version.matches(">= 20.07.1") ){
    nextflow.enable.dsl=2
} else {
    // Support lower version of nextflow
    nextflow.preview.dsl=2
}


/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

def helpMessage() {
    log.info"""
    ccsmethphase - Nextflow PIPELINE (v$workflow.manifest.version)
    =================================
    Usage:
    The typical command is as follows:

    nextflow run ~/tools/ccsmethphase -profile
    Mandatory arguments:
      --input       Input path for pacbio bam files (folders, tar/tar.gz files)
      --genome      Genome reference name ('hg38', 'ecoli', or 'hg38_chr22') or a directory, the directory must contain only one .fasta file with .fasta.fai index file. Default is hg38
      --dsname      Dataset/analysis name

    General options:
      --outdir      Output dir
      --chrSet      Chromosomes used in analysis, default is chr1-22, X and Y, for human. For E. coli data, it is default as 'NC_000913.3'. For other reference genome, please specify each chromosome with space seperated.
      --cleanup     If clean work dir after complete, default is false

    Tools specific options:


    Running environment options:
      --docker_name     Docker name used for pipeline, default is '/:latest'
      --singularity_name    Singularity name used for pipeline, default is 'docker:///:latest'
      --singularity_cache   Singularity cache dir, default is 'local_singularity_cache'
      --conda_name      Conda name used for pipeline, default is 'nanome'
      --conda_base_dir  Conda base directory, default is '/opt/conda'

    -profile options:
      Use this parameter to choose a predefined configuration profile. Profiles can give configuration presets for different compute environments.

      test      A test demo config
      docker    A generic configuration profile to be used with Docker, pulls software from Docker Hub: /:latest
      singularity   A generic configuration profile to be used with Singularity, pulls software from: docker:///:latest
      conda     Please only use conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity. Check our GitHub for how to install local conda environment

    """.stripIndent()
}


// check input =====================================================================
// Show help message
if ( params.help ){
    helpMessage()
    exit 0
}


if ( !params.genome ){
    exit 1, "--genome option not specified!"
}


if ( params.eval_methcall && !params.bs_bedmethyl ){
    exit 1, "--eval_methcall is set as true, but there is no --bs_bedmethyl specified!"
}


genome_map = params.genomes
if ( params.genome && genome_map[params.genome] ) { genome_path = genome_map[params.genome] }
else {  genome_path = params.genome }


// infer dataType, chrSet based on reference genome name, hg - human, ecoli - ecoli, otherwise is other reference genome
if ( params.genome.contains('hg') || params.genome.contains('GRCh38') || params.genome.contains('GRCh37') || (params.dataType && params.dataType == 'human') ) {
    dataType = "human"
    if (!params.chrSet) {
        // default for human, if false or 'false' (string), using '  '
        chrSet = 'chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY'
    } else {
        chrSet = params.chrSet
    }
} else if ( params.genome.contains('ecoli') || (params.dataType && params.dataType == 'ecoli') ) {
    dataType = "ecoli"
    if (!params.chrSet) {
        // default for ecoli
        chrSet = 'NC_000913.3'
    } else {
        chrSet = params.chrSet
    }
} else {
    // default will not found name, use other
    if ( !params.dataType ) { dataType = 'other' } else { dataType = params.dataType }
    if ( !params.chrSet ) {
        // No default value for other reference genome
        if ( !file(params.genome+".contig_names.txt").exists() ){
            // exit 1, "Missing --chrSet option for other reference genome, please specify chromosomes used in reference genome [${params.genome}], or use utils/extract_contig_names_from_fasta.py to create one"
        } else {
            //Channel.fromPath( params.genome+".contig_names.txt", type: 'file', checkIfExists: true )
            //.first(String)
            //.set{chrSet}
        }
        
    }
    else { 
        chrSet = params.chrSet 
    }
}


// set utils dirs
projectDir = workflow.projectDir
ch_utils = Channel.value("${projectDir}/utils")


// set files used for evaluation
if ( params.eval_methcall ) {
    bs_bedmethyl_file = Channel.fromPath(params.bs_bedmethyl,  type: 'file', checkIfExists: true)
    // bs_bedmethyl_file = Channel.value(params.bs_bedmethyl)
} else {
    bs_bedmethyl_file = Channel.empty()
}


// generate input files, and send into Channels for pipelines
if ( params.input.endsWith(".filelist.txt") ) {
    // list of files in filelist.txt
    Channel.fromPath( params.input, checkIfExists: true )
        .splitCsv(header: false)
        .map {
            if (!file(it[0]).exists())  {
                log.warn "File not exists: ${it[0]}, check file list: ${params.input}"
            } else {
                return file(it[0])
            }
        }
        .set{ pacbio_bam }
} else if ( params.input.contains('*') || params.input.contains('?') ) {
    // match all files in the folder, note: input must use '', prevent expand in advance
    // such as --input '/fastscratch/liuya/nanome/NA12878/NA12878_CHR22/input_chr22/*'
    Channel.fromPath(params.input, type: 'any', checkIfExists: true)
        .set{ pacbio_bam }
} else {
    // For single file/wildcard matched files
    Channel.fromPath( params.input, checkIfExists: true ).set{ pacbio_bam }
}


// TODO: set summary
def summary = [:]
summary['input']            = params.input


// import modules
include { EnvCheck                     } from './modules/envcheck'
include { SAMTOOLS_index_bam           } from './modules/samtools_index_bam'
include { CCSMETH_pbccs_call_hifi      } from './modules/ccsmeth_pbccs_call_hifi'
include { CCSMETH_call_mods_denovo     } from './modules/ccsmeth_call_mods'
include { CCSMETH_align_hifi           } from './modules/ccsmeth_align_hifi'
include { SAMTOOLS_merge_sortedbams    } from './modules/samtools_merge_sortedbams'
include { CLAIR3_hifi                  } from './modules/clair3_hifi'
include { WHATSHAP_snv_phase_haplotag  } from './modules/whatshap_snv_phase_haplotag'
include { CCSMETH_call_freq_bam        } from './modules/ccsmeth_call_freq_bam'


/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/
workflow {
    if ( !file(params.genome).exists() )
        exit 1, "genome reference path does not exist, check params: --genome ${params.genome}"

    genome_ch = Channel.fromPath(genome_path, type: 'any', checkIfExists: true)

    if ( !params.run_call_mods ) {
        // use null placeholder
        ccsmeth_cm_model = Channel.value("${projectDir}/utils/null2")
    }
    else {
        if ( !file(params.ccsmeth_cm_model.toString()).exists() ) {
            ccsmeth_cm_model = Channel.value("${projectDir}/utils/null2")
        }
        else {
            ccsmeth_cm_model = Channel.fromPath(params.ccsmeth_cm_model, type: 'file', checkIfExists: true)
        }
    }

    EnvCheck(ccsmeth_cm_model, genome_ch)

    // call_hifi
    hifi_bam = Channel.empty()
    if ( params.run_call_hifi ) {
        CCSMETH_pbccs_call_hifi(pacbio_bam, ch_utils)
        CCSMETH_pbccs_call_hifi.out.hifi_bambai.set{hifi_bam}
    } else {
        SAMTOOLS_index_bam(pacbio_bam)
        SAMTOOLS_index_bam.out.bambai.set{pacbio_bambai}
        pacbio_bam.map({file -> [file.baseName, file]})
                  .join(pacbio_bambai)
                  .map({it -> [it[1], it[2]]})
                  .set{hifi_bam}
    }

    // call_mods
    modbam = Channel.empty()
    if ( params.run_call_mods ) {
        CCSMETH_call_mods_denovo(hifi_bam, EnvCheck.out.ccsmeth_cm_model_ckpt, ch_utils)
        CCSMETH_call_mods_denovo.out.ccsmeth_modbam.set{modbam}
    } else {
        hifi_bam.set{modbam}
    }

    // align and post_align
    if ( params.run_align ) {
        CCSMETH_align_hifi(modbam, EnvCheck.out.reference_genome_dir, ch_utils)

        // merge, sort, index all aligned bam
        if ( params.postalign_combine ) {

            def criteria = multiMapCriteria {
                bam: [it[0], it[1]]
                bai: [it[0], it[2]]
            }
            CCSMETH_align_hifi.out.align_bam.multiMap(criteria).set{aligned_bambai}

            SAMTOOLS_merge_sortedbams(aligned_bambai.bam.map({it -> it[1]}).collect(),
                                      aligned_bambai.bai.map({it -> it[1]}).collect())
            SAMTOOLS_merge_sortedbams.out.merged_bam.set{postalign_bam}
        } else {
            CCSMETH_align_hifi.out.align_bam.set{postalign_bam}
        }

        // clair3
        if ( params.run_clair3 ) {
            CLAIR3_hifi(postalign_bam, EnvCheck.out.reference_genome_dir)

            // whatshap
            if ( params.run_whatshap ) {
                CLAIR3_hifi.out.clair3_vcf.join(postalign_bam).set{vcf_and_aligned_bam}
                WHATSHAP_snv_phase_haplotag(vcf_and_aligned_bam, EnvCheck.out.reference_genome_dir)
                WHATSHAP_snv_phase_haplotag.out.phased_vcf_bam.map({ it -> [it[0], it[3], it[4]] })
                                                              .set{phased_bam}
            } else {
                postalign_bam.set{phased_bam}
            }
        } else {
            postalign_bam.set{phased_bam}
        }

        // ccsmeth call_freq
        if ( params.run_call_mods && params.run_call_freq ) {
            CCSMETH_call_freq_bam(phased_bam, EnvCheck.out.reference_genome_dir, ch_utils)
        }
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
