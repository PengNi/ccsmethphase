# Set the base image to Ubuntu and NVIDIA GPU from https://hub.docker.com/r/nvidia/cuda
# or from https://ngc.nvidia.com/catalog/containers/nvidia:cuda/tags
# 11.0, 11.0.3, 10.2, 10.1, 9.2 for torch 1.7.0; 10.2 is ok for 1.7.0-1.11.0
FROM nvidia/cuda:10.2-cudnn8-runtime-ubuntu18.04

# Author and maintainer
MAINTAINER Peng Ni <543943952@qq.com>
LABEL description="ccsmethphase" \
      author="543943952@qq.com"

ARG DNAME="ccsmethphase"

# shouldn't do this?
# ENV CUDA_HOME /usr/local/cuda
# ENV PATH ${CUDA_HOME}/bin:$PATH
# ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:${CUDA_HOME}/compat/:${CUDA_HOME}/lib64/

ARG BUILD_PACKAGES="wget apt-transport-https procps git curl"
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get -q update && \
    DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get -q install --yes ${BUILD_PACKAGES} && \
    apt-get autoremove --purge --yes && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#Install miniconda
RUN wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda.sh && \
    /bin/bash Miniconda.sh -b -p /opt/conda && \
    rm Miniconda.sh

# Adding conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Create the environment:
COPY environment.yml /
RUN conda env create --name ${DNAME} --file=environment.yml

## install clair3
## https://github.com/HKU-BAL/Clair3/blob/main/Dockerfile
#COPY environment-clair3.yml /
#RUN conda env create --name clair3 --file=environment-clair3.yml

RUN conda clean -a

# Make RUN commands use the new environment
# name need to be the same with the above ${DNAME}
SHELL ["conda", "run", "-n", "ccsmethphase", "/bin/bash", "-c"]

# Set env path into PATH
ENV PATH /opt/conda/envs/${DNAME}/bin:$PATH
USER root
WORKDIR /data/

RUN cd /data

CMD ["bash"]
