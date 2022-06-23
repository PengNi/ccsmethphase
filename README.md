# ccsmethphase

A demo nextflow pipeline of methylation detection using long reads


## Contents
* [Installation](#Installation)
* [Usage](#Usage)
* [Acknowledgements](#Acknowledgements)
* [TODO](#TODO)


## Installation

  - (1) Install conda from [Conda](https://docs.conda.io/projects/conda/en/latest/user-guide/install/linux.html) if neeeded.


  - (2) Install nextflow.

Create an environment containing nextflow/install nextflow:
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

### Option 1. 


## Acknowledgements
  - Some code were taken from [nanome](https://github.com/TheJacksonLaboratory/nanome) and [nf-core](https://github.com/nf-core).

developement: [nextflow_develop.md](docs/nextflow_develop.md)
