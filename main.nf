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
if ( params.input.endsWith(".txt") || params.input.endsWith(".tsv") ) {
    Channel.fromPath( params.input, checkIfExists: true )
        .splitCsv(header: true, sep: "\t", strip: true)
        .map{ it -> [it.Group_ID, it.Sample_ID, it.Type.toLowerCase(), file(it.Path)] }
        .filter{ it[3].exists() }
        .set{ pacbio_bam }
} else {
    exit 1, "--input must be in tsv format, see ccsmethphase/demo/input_sheet.tsv for more information!"
}


// TODO: set summary
def summary = [:]
summary['input']            = params.input


// import modules
include { CheckGenome                  } from './modules/envcheck'
include { CheckCMModel                 } from './modules/envcheck'
include { CheckAGModel                 } from './modules/envcheck'
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

    // TODO: there are case that user doesn't use default model path, but
    // TODO: sets his own model path the same as DEFAULT_CCSMETH_CM_MODEL.
    // TODO: In this case, this code will still use the DEFAULT_CCSMETH_CM_MODEL,
    // TODO: which maybe not appropriate.
    // TODO: ccsmeth_cm_model/ccsmeth_ag_model both has this issue
    // TODO: [check also envcheck.nf, ccsmeth_call_mods.nf, ccsmeth_call_freq_bam.nf]
    if ( !params.run_call_mods ) {
        // use null placeholder
        ccsmeth_cm_model = Channel.value("${projectDir}/utils/null2")
    }
    else {
        if ( params.ccsmeth_cm_model == params.DEFAULT_CCSMETH_CM_MODEL ) {
            ccsmeth_cm_model = Channel.value("${projectDir}/utils/null2")
        }
        else if ( !file(params.ccsmeth_cm_model.toString()).exists() ) {
            exit 1, "ccsmeth_cm_model does not exist, check params: --ccsmeth_cm_model ${params.ccsmeth_cm_model}"
        }
        else {
            ccsmeth_cm_model = Channel.fromPath(params.ccsmeth_cm_model, type: 'file', checkIfExists: true)
        }
    }

    if ( params.run_call_mods && params.run_call_freq && params.cf_mode == "aggregate" ) {
        if ( params.ccsmeth_ag_model == params.DEFAULT_CCSMETH_AG_MODEL ) {
            ccsmeth_ag_model = Channel.value("${projectDir}/utils/null3")
        }
        else if ( !file(params.ccsmeth_ag_model.toString()).exists() ) {
            exit 1, "ccsmeth_ag_model does not exist, check params: --ccsmeth_ag_model ${params.ccsmeth_ag_model}"
        }
        else {
            ccsmeth_ag_model = Channel.fromPath(params.ccsmeth_ag_model, type: 'file', checkIfExists: true)
        }
    }
    else {
        // use null placeholder
        ccsmeth_ag_model = Channel.value("${projectDir}/utils/null3")
    }

    CheckGenome(genome_ch)
    CheckCMModel(ccsmeth_cm_model)
    CheckAGModel(ccsmeth_ag_model)

    // input_bam -> call_hifi or index
    hifi_bam = Channel.empty()
    pacbio_bam.branch {
        hifi: it[2] == "hifi" || it[2] == "ccs"
        subreads: it[2] == "subreads"
        other: true
    }.set{pacbio_bam_splited}
    pacbio_bam_splited.other.view(it -> "item ${it[0]} - ${it[1]} - ${it[2]} - ${it[3]} is neither hifi reads nor subreads, please re-edit it!")
    // TODO: how to make the following run only if there are >0 items in pacbio_bam_splited.subreads/pacbio_bam_splited.hifi?
    // TODO: maybe combine CCSMETH_pbccs_call_hifi and SAMTOOLS_index_bam into one process?
    CCSMETH_pbccs_call_hifi(pacbio_bam_splited.subreads.map{it -> [it[0], it[1], it[3]]}, ch_utils)
    CCSMETH_pbccs_call_hifi.out.hifi_bambai.set{hifi_bam_called}
    SAMTOOLS_index_bam(pacbio_bam_splited.hifi.map{it -> [it[0], it[1], it[3]]})
    SAMTOOLS_index_bam.out.bambai.set{hifi_bam_indexed}
    hifi_bam_indexed.concat(hifi_bam_called).set{hifi_bam}

    // call_mods
    modbam = Channel.empty()
    if ( params.run_call_mods ) {
        CCSMETH_call_mods_denovo(hifi_bam, CheckCMModel.out.ccsmeth_cm_model_ckpt, ch_utils)
        CCSMETH_call_mods_denovo.out.ccsmeth_modbam.set{modbam}
    } else {
        hifi_bam.set{modbam}
    }

    // align and post_align
    if ( params.run_align ) {
        CCSMETH_align_hifi(modbam, CheckGenome.out.reference_genome_dir, ch_utils)

        // merge, sort, index all aligned bam by sample_id
        SAMTOOLS_merge_sortedbams(CCSMETH_align_hifi.out.align_bam.groupTuple(by: [0,1]))
        SAMTOOLS_merge_sortedbams.out.merged_bam.set{merged_bam}

        // clair3
        if ( params.run_clair3 ) {
            CLAIR3_hifi(merged_bam, CheckGenome.out.reference_genome_dir)

            // whatshap
            if ( params.run_whatshap ) {
                CLAIR3_hifi.out.clair3_vcf.join(merged_bam, by: [0,1]).set{vcf_and_aligned_bam}
                WHATSHAP_snv_phase_haplotag(vcf_and_aligned_bam, CheckGenome.out.reference_genome_dir)
                WHATSHAP_snv_phase_haplotag.out.phased_vcf_bam.map( {it -> [it[0], it[1], it[4], it[5]]} )
                                                              .set{phased_bam}
            } else {
                merged_bam.set{phased_bam}
            }
        } else {
            merged_bam.set{phased_bam}
        }

        // ccsmeth call_freq
        if ( params.run_call_mods && params.run_call_freq ) {
            CCSMETH_call_freq_bam(phased_bam, CheckGenome.out.reference_genome_dir,
                                  CheckAGModel.out.ccsmeth_ag_model_ckpt, ch_utils)
        }
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
