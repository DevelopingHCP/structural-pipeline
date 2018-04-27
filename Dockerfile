## Build Docker image for execution of dhcp pipelines within a Docker
## container with all modules and applications available in the image

FROM ubuntu:xenial
MAINTAINER John Cupitt <jcupitt@gmail.com>
LABEL Description="dHCP structural-pipeline" Vendor="BioMedIA"

# Git repository and commit SHA from which this Docker image was built
# (see https://microbadger.com/#/labels)
ARG VCS_REF
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/biomedia/dhcp-structural-pipeline"

# No. of threads to use for build (--build-arg THREADS=8)
# By default, all available CPUs are used. 
ARG THREADS

# install prerequsites
# - build tools
# - FSL latest
#	  * -E is not suported on ubuntu (rhel only), so we make a quick n dirty
#	    /etc/fsl/fsl.sh 
#	  * fslinstaller.py fails in post_install as it gives the wrong flag to wget
#	    to enable silent mode ... run the post install again to fix this

RUN apt-get update 
RUN apt-get install -y \
	wget g++-5 git cmake unzip bc python python-contextlib2 \
	libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev \
	libgstreamer1.0-dev libqt4-dev
COPY . /usr/src/structural-pipeline
RUN cd /usr/src/structural-pipeline \
	&& echo "please ignore the 'failed to download miniconda' error coming soon" \
	&& python fslinstaller.py -V 5.0.11 -q -d /usr/local/fsl \
	&& export FSLDIR=/usr/local/fsl \
	&& echo "retrying miniconda install ..." \
	&& /usr/local/fsl/etc/fslconf/post_install.sh \
  && mkdir -p /etc/fsl \
	&& echo "FSLDIR=/usr/local/fsl; . \${FSLDIR}/etc/fslconf/fsl.sh; PATH=\${FSLDIR}/bin:\${PATH}; export FSLDIR PATH" > /etc/fsl/fsl.sh 

RUN NUM_CPUS=${THREADS:-`cat /proc/cpuinfo | grep processor | wc -l`} \
	&& echo "Maximum number of build threads = $NUM_CPUS" \
	&& cd /usr/src/structural-pipeline \
	&& ./setup.sh -j $NUM_CPUS

WORKDIR /data
ENTRYPOINT ["/usr/src/structural-pipeline/dhcp-pipeline.sh"]
CMD ["-help"]

