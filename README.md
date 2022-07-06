# ccsmethphase

Methylation phasing using PacBio CCS reads


## Contents
* [Installation](#Installation)
* [Demo data](#Demo-data)
* [Usage](#Usage)
* [Acknowledgements](#Acknowledgements)
* [TODO](#TODO)


## Installation

  - (1) Install conda from [Conda](https://docs.conda.io/projects/conda/en/latest/user-guide/install/linux.html) if neeeded.


  - (2) Install [nextflow](https://www.nextflow.io/) (version>=21.10.6).

```sh
# create a new environment and install nextflow in it
conda create -n nextflow -c conda-forge -c bioconda nextflow

# OR, install nextflow in an existing environment
conda install -c conda-forge -c bioconda nextflow
```

  - (3) Download ccsmethphase from github.

```sh
git clone https://github.com/PengNi/ccsmethphase.git
```

  - (4) Install [Docker](https://docs.docker.com/engine/install/) or [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/) if needed.

  - (5) [optional] Install graphviz.

```sh
sudo apt install graphviz
# or
sudo yum install graphviz
```


## Demo data
Check [ccsmethphase/demo](/demo) for demo data:
  - _hg002.chr20_demo.hifi.bam_: HG002 demo hifi reads which align to human genome chr20:10000000-10100000.
  - _chr20_demo.fa_: reference sequence of human chr20:10000000-10100000.
  - _hg002_bsseq_chr20_demo.bed_: HG002 BS-seq results of region chr20:10000000-10100000.

Check also [ccsmeth](https://github.com/PengNi/ccsmeth) to get ccsmeth CpG models. 


## Usage
ccsmethphase takes PacBio subreads.bam (or hifi.bam), genome reference, and ccsmeth models as input.

Input format of pacbio_reads:
  - .

### Option 1. Run with singularity (recommended)

If it is the first time you run with singularity (e.g. using `-profile singularity`), the following cmd will cache the dafault singularity image (`--singularity_name` and/or `--clair3_singularity_name`) to the `--singularity_cache` directory (default: `local_singularity_cache`) first. There will be `.img` file(s) in the `--singularity_cache` directory.

```sh
# activate nextflow environment
conda activate nextflow

# this cmd will cache a singularity image first if there is none
# set --run_call_hifi to false, as the input is hifi.bam
# set --include_all_ctgs to true to include all contigs,
#   default false, means only [chr][1-22+XY] included
nextflow run /path/to/ccsmethphase \
    --dsname test \
    --genome /path/to/ccsmethphase/demo/chr20_demo.fa \
    --input "/path/to/ccsmethphase/demo/hg002.chr20_demo.hifi.bam" \
    --ccsmeth_cm_model /path/to/ccsmeth_cm_model.ckpt \
    --run_call_hifi false --include_all_ctgs true \
    -profile singularity
# or, set CUDA_VISIBLE_DEVICES to use GPU
CUDA_VISIBLE_DEVICES=0 nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome /path/to/ccsmethphase/demo/chr20_demo.fa \
    --input "/path/to/ccsmethphase/demo/hg002.chr20_demo.hifi.bam" \
    --ccsmeth_cm_model /path/to/ccsmeth_cm_model.ckpt \
    --run_call_hifi false --include_all_ctgs true \
    -profile singularity
```

The downloaded `.img` file(s) can be re-used then, without being downloaded again:

```sh
nextflow run ~/path/to/ccsmethphase \
    --dsname test2 \
    --genome /path/to/some-other/genome/fa \
    --input "/path/to/some-other.subreads.bam" \
    --ccsmeth_cm_model /path/to/ccsmeth_cm_model.ckpt \
    -profile singularity
# or specify the directory where the images are
nextflow run ~/path/to/ccsmethphase \
    --dsname test2 \
    --genome /path/to/some-other/genome/fa \
    --input "/path/to/some-other.subreads.bam" \
    --ccsmeth_cm_model /path/to/ccsmeth_cm_model.ckpt \
    -profile singularity \
    --singularity_cache local_singularity_cache
```

### Extra 1. Resume a run
Try `-resume` to re-run a modified/failed job to save time:

```shell
nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome /path/to/ccsmethphase/demo/chr20_demo.fa \
    --input "/path/to/ccsmethphase/demo/hg002.chr20_demo.hifi.bam" \
    --ccsmeth_cm_model /path/to/ccsmeth_cm_model.ckpt \
    --run_call_hifi false --include_all_ctgs true \
    -profile singularity \
    -resume
```


## Acknowledgements
  - Some code were taken from [nanome](https://github.com/TheJacksonLaboratory/nanome) and [nf-core](https://github.com/nf-core).


## TODO
  - input format -> `group_id    type(hifi/subreads)    file_abs_path`
  - have tested docker on cpu, singularity on cpu/gpu/cpu-in-gpu-machine; did not test docker on gpu/cpu-in-gpu-machine yet
