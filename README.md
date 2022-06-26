# ccsmethphase

Methylation phasing using PacBio CCS reads


## Contents
* [Installation](#Installation)
* [Usage](#Usage)
* [Acknowledgements](#Acknowledgements)
* [TODO](#TODO)


## Installation

  - (1) Install conda from [Conda](https://docs.conda.io/projects/conda/en/latest/user-guide/install/linux.html) if neeeded.


  - (2) Install nextflow (version>=21.10.6).

```sh
# create a new environment and install nextflow in it
conda create -n nextflow -c conda-forge -c bioconda nextflow

# or install nextflow in an existing environment
conda install -c conda-forge -c bioconda nextflow
```

  - (3) Download ccsmethphase from github.

```sh
git clone https://github.com/PengNi/ccsmethphase.git
```

  - (4) [optional] Install graphviz.

```sh
sudo apt install graphviz
# or
sudo yum install graphviz
```


## Usage
ccsmethphase accepts PacBio subreads.bam (or hifi.bam), genome reference, and ccsmeth models as input.

### Option 1. Run with singularity (recommended)

If it is the first time you run with singularity (e.g. using `-profile singularity`), the following cmd will cache the dafault singularity image (`--singularity_name` and/or `--clair3_singularity_name`) to the `--singularity_cache` directory (default: `local_singularity_cache`) first. There will be `.img` file(s) in the `--singularity_cache` directory.

```sh
# activate nextflow environment
conda activate nextflow

# run longmethyl, this cmd will cache a singularity image before processing the data
nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome chm13v2.0.fa \
    --input "some.subreads.bam" \
    --ccsmeth_cm_model ccsmeth_cm_model.ckpt \
    -profile singularity
# or, run longmethyl using GPU, set CUDA_VISIBLE_DEVICES
CUDA_VISIBLE_DEVICES=0 nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome chm13v2.0.fa \
    --input "some.subreads.bam" \
    --ccsmeth_cm_model ccsmeth_cm_model.ckpt \
    -profile singularity
```

The downloaded `.img` file(s) can be re-used then, without being downloaded again:

```sh
# this time nextflow will not download the singularity images again.
nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome chm13v2.0.fa \
    --input "some_other.subreads.bam" \
    --ccsmeth_cm_model ccsmeth_cm_model.ckpt \
    -profile singularity
# or specify the directory where the images are in
nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome chm13v2.0.fa \
    --input "some_other.subreads.bam" \
    --ccsmeth_cm_model ccsmeth_cm_model.ckpt \
    -profile singularity \
    --singularity_cache local_singularity_cache
```

### Option 2. Resume a run
Try `-resume` to re-run a modified/failed job to save time:

```shell
nextflow run ~/path/to/ccsmethphase \
    --dsname test \
    --genome chm13v2.0.fa \
    --input "some.subreads.bam" \
    --ccsmeth_cm_model ccsmeth_cm_model.ckpt \
    -profile singularity \
    -resume
```


## Acknowledgements
  - Some code were taken from [nanome](https://github.com/TheJacksonLaboratory/nanome) and [nf-core](https://github.com/nf-core).


## TODO
  - input format -> `group_id    type(hifi/subreads)    file_abs_path`
