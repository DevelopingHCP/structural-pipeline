## Build Docker image for execution of dhcp pipelines within a Docker
## container with all modules and applications available in the image
##
## How to build the image:
## - Change to top-level directory of structural-pipeline source tree
## - Run "docker build --build-arg VCS_REF=`git rev-parse --short HEAD` -t <user>/structural-pipeline:latest ."
##
## Upload image to Docker Hub:
## - Log in with "docker login" if necessary
## - Push image using "docker push <user>/structural-pipeline:latest"
##

FROM ubuntu:xenial
MAINTAINER John Cupitt <jcupitt@gmail.com>
LABEL Description="dHCP structural-pipeline" Vendor="BioMedIA"

# Git repository and commit SHA from which this Docker image was built
# (see https://microbadger.com/#/labels)
ARG VCS_REF
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/DevelopingHCP/structural-pipeline"

# No. of threads to use for build (--build-arg THREADS=8)
# By default, all available CPUs are used. When a Docker Machine is used,
# set the number of CPUs in the VirtualBox VM Settings.
ARG THREADS

# install prerequsites
# - FSL
# - build tools

RUN apt-get update 
RUN apt-get install -y apt-utils wget 
RUN wget -O- http://neuro.debian.net/lists/artful.de-m.full | tee /etc/apt/sources.list.d/neurodebian.sources.list 
RUN apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 
RUN apt-get update 
RUN apt-get install -y \
	fsl-complete \
	g++-5 git cmake unzip bc python python-contextlib2 \
	libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev \
	libgstreamer1.0-dev libqt4-dev

COPY . /usr/src/structural-pipeline
RUN ls /usr/src/structural-pipeline \
    && NUM_CPUS=${THREADS:-`cat /proc/cpuinfo | grep processor | wc -l`} \
    && echo "Maximum number of build threads = $NUM_CPUS" \
    && cd /usr/src/structural-pipeline \
    && ./setup.sh -j $NUM_CPUS

