#!/usr/bin/env nextflow
/*
========================================================================================
    ccsmethphase
========================================================================================
    Github : https://github.com/
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
      --input       Input path for raw fast5 files (folders, tar/tar.gz files)
      --genome      Genome reference name ('hg38', 'ecoli', or 'hg38_chr22') or a directory, the directory must contain only one .fasta file with .fasta.fai index file. Default is hg38
      --dsname      Dataset/analysis name

    General options:
      --outdir      Output dir, default is 'results'
      --chrSet      Chromosomes used in analysis, default is chr1-22, X and Y, for human. For E. coli data, it is default as 'NC_000913.3'. For other reference genome, please specify each chromosome with space seperated.
      --cleanAnalyses   If clean old basecalling info in fast5 files
      --cleanup     If clean work dir after complete, default is false

    Tools specific options:


    Running environment options:
      --docker_name     Docker name used for pipeline, default is '/:latest'
      --singularity_name    Singularity name used for pipeline, default is 'docker:///:latest'
      --singularity_cache   Singularity cache dir, default is 'local_singularity_cache'
      --conda_name      Conda name used for pipeline, default is 'nanome'
      --conda_base_dir  Conda base directory, default is '/opt/conda'
      --conda_cache     Conda cache dir, default is 'local_conda_cache'

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
if (params.help){
    helpMessage()
    exit 0
}


if (!params.genome){
    exit 1, "--genome option not specified!"
}


if (params.eval_methcall && !params.bs_bedmethyl){
    exit 1, "--eval_methcall is set as true, but there is no --bs_bedmethyl specified!"
}


genome_map = params.genomes

if (params.genome && genome_map[params.genome]) { genome_path = genome_map[params.genome] }
else {  genome_path = params.genome }


// infer dataType, chrSet based on reference genome name, hg - human, ecoli - ecoli, otherwise is other reference genome
if (params.genome.contains('hg') || params.genome.contains('GRCh38') || params.genome.contains('GRCh37') || (params.dataType && params.dataType == 'human')) {
    dataType = "human"
    if (!params.chrSet) {
        // default for human, if false or 'false' (string), using '  '
        chrSet = 'chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY'
    } else {
        chrSet = params.chrSet
    }
} else if (params.genome.contains('ecoli') || (params.dataType && params.dataType == 'ecoli')) {
    dataType = "ecoli"
    if (!params.chrSet) {
        // default for ecoli
        chrSet = 'NC_000913.3'
    } else {
        chrSet = params.chrSet
    }
} else {
    // default will not found name, use other
    if (!params.dataType) { dataType = 'other' } else { dataType = params.dataType }
    if (!params.chrSet) {
        // No default value for other reference genome
        if (!file(params.genome+".contig_names.txt").exists()){
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

// set utils/src dirs 
projectDir = workflow.projectDir
// ch_utils = Channel.fromPath("${projectDir}/utils",  type: 'dir', followLinks: false)
// ch_src   = Channel.fromPath("${projectDir}/src",  type: 'dir', followLinks: false)
ch_utils = Channel.value("${projectDir}/utils")
ch_src   = Channel.value("${projectDir}/src")

if (params.eval_methcall) {
    bs_bedmethyl_file = Channel.fromPath(params.bs_bedmethyl,  type: 'file', checkIfExists: true)
    // bs_bedmethyl_file = Channel.value(params.bs_bedmethyl)
} else {
    bs_bedmethyl_file = Channel.empty()
}

// Collect all folders of fast5 files, and send into Channels for pipelines
if (params.input.endsWith(".filelist.txt")) {
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
        .set{ fast5_tar_ch }
} else if (params.input.contains('*') || params.input.contains('?')) {
    // match all files in the folder, note: input must use '', prevent expand in advance
    // such as --input '/fastscratch/liuya/nanome/NA12878/NA12878_CHR22/input_chr22/*'
    Channel.fromPath(params.input, type: 'any', checkIfExists: true)
        .set{ fast5_tar_ch }
} else {
    // For single file/wildcard matched files
    Channel.fromPath( params.input, checkIfExists: true ).set{ fast5_tar_ch }
}





// TODO: set summary
def summary = [:]
summary['input']            = params.input


// Reference genome
def referenceGenome = 'reference_genome/ref.fasta'

// Check all tools work well
process EnvCheck {
    tag "envcheck"
    errorStrategy 'terminate'

    label 'process_low'

    input:
    path ch_utils
    path deepsignalDir
    path reference_genome

    output:
    path "reference_genome",                emit: reference_genome, optional: true
    path "${params.DEEPSIGNAL_MODEL_DIR}",  emit: deepsignal_model, optional: true

    script:
    """
    date; hostname; pwd
    echo "CUDA_VISIBLE_DEVICES=\${CUDA_VISIBLE_DEVICES:-}"

    ## Untar and prepare deepsignal model
    if [ ${params.runDeepSignal} == true ]; then
        if [ ${deepsignalDir} == *.tar.gz ] ; then
            ## Get DeepSignal Model online
            tar -xzf ${deepsignalDir}
        elif [[ ${deepsignalDir} != ${params.DEEPSIGNAL_MODEL_DIR} && -d ${deepsignalDir} ]] ; then
            ## rename it to deepsignal default dir name
            cp -a ${deepsignalDir}  ${params.DEEPSIGNAL_MODEL_DIR}
        fi
        ## Check DeepSignal model
        ls -lh ${params.DEEPSIGNAL_MODEL_DIR}/
    fi

    if [[ ${params.runBasecall} == true || ${params.runDeepSignal} == true ]]; then
        ## Get dir for reference_genome
        mkdir -p reference_genome
        find_dir="\$PWD/reference_genome"
        if [[ ${reference_genome} == *.tar.gz && -f ${reference_genome}  ]] ; then
            tar -xzf ${reference_genome} -C reference_genome
        elif [[ ${reference_genome} == *.tar && -f ${reference_genome} ]] ; then
            tar -xf ${reference_genome} -C reference_genome
        elif [[ -d ${reference_genome} ]] ; then
            ## for folder, use ln, note this is a symbolic link to a folder
            find_dir=\$( readlink -f ${reference_genome} )
        elif [[ -e ${reference_genome} ]] ; then
            cp ${reference_genome} \${find_dir}/${reference_genome}.ori.fasta
        else
            echo "### ERROR: not recognized reference_genome=${reference_genome}"
            exit -1
        fi

        find \${find_dir} -name '*.fasta*' | \
            parallel -j0 -v  'fn={/} ; ln -s -f  {}   reference_genome/\${fn/*.fasta/ref.fasta}'
        ## find \${find_dir} -name '*.sizes' | \
        ##         parallel -j1 -v ln -s -f {} reference_genome/chrom.sizes

        ls -lh reference_genome/
    fi

    echo "### Check env"
    echo "cpus=$task.cpus"
    echo "referenceGenome=${referenceGenome}"
    echo "### Check env DONE"
    """
}


/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/
workflow {
    if ( !file(params.genome).exists() )
        exit 1, "genome reference path does not exist, check params: --genome ${params.genome}"

    genome_ch = Channel.fromPath(genome_path, type: 'any', checkIfExists: true)

    if (! params.runDeepSignal) {
        // use null placeholder
        // deepsignalDir = Channel.fromPath("${projectDir}/utils/null2", type: 'any', checkIfExists: true)
        deepsignalDir = Channel.value("${projectDir}/utils/null2")
    }
    else {
        // User provide the dir
        if ( !file(params.deepsignalDir.toString()).exists() )
            exit 1, "deepsignalDir does not exist, check params: --deepsignalDir ${params.deepsignalDir}"
        deepsignalDir = Channel.fromPath(params.deepsignalDir, type: 'any', checkIfExists: true)
    }

    EnvCheck(ch_utils, deepsignalDir, genome_ch)

}

/*
========================================================================================
    THE END
========================================================================================
*/
