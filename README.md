# dHCP structural pipeline
==========================================

Installation
------------
Prerequisites:
- FSL


Dependencies
------------


macos 10.9.5:
brew install gcc git cmake unzip
brew install tbb boost cartr/qt4/qt
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation

Red Hat Enterprise Linux RHEL-7.3:
sudo yum -y update
sudo yum -y install gcc-c++ git cmake unzip
sudo yum -y install python tbb-devel boost-devel qt-devel zlib-devel libXt-devel
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation

Ubuntu 16.04 or Debian GNU/Linux 8:
sudo apt-get -y update
sudo apt-get -y install g++ git cmake unzip
sudo apt-get -y install python libtbb-dev libboost-dev libqt4-dev zlib1g-dev libxt-dev
  http://neuro.debian.net/install_pkg.html?p=fsl-complete
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup





undefined reference to `vnl_vector<int>::operator=(vnl_vector
# qtdeclarative5-dev






git clone https://gitlab.doc.ic.ac.uk/am411/structural-pipeline.git
cd structural-pipeline
./setup.sh -j 8

nohup ./setup.sh -j 8 &




FSLDIR=/usr/share/fsl/5.0
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLDIR PATH

cd ~/pipeline-test
nohup ./run.sh >log &





overview table libraries/dependencies, links to licenses

discuss: libraries, setup packages, fsl, N4 care, path, licences



Run
------------
- A single subject pipeline can be run using the ./pipelines/dhcp-pipeline-v2.3.sh 
Running it without parameters will display the possible options.

- The run folder contains scripts for the execution within the dHCP file structure (main file: run/run.sh)
