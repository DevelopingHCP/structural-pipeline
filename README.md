# dHCP structural pipeline
==========================================

Installation
------------
Prerequisites:
- FSL


Dependencies
------------


macos 10.9.5:
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update
brew install gcc git cmake unzip tbb boost cartr/qt4/qt
sudo easy_install pip
pip install contextlib2
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup

Red Hat Enterprise Linux RHEL-7.3:
sudo yum -y update
sudo yum -y install gcc-c++ git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel gstreamer1-devel
curl -o epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum -y install epel.rpm
sudo yum -y install python-contextlib2
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup


CENTOS 7:
sudo yum -y update
sudo yum -y install gcc-c++ git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel gstreamer1-devel 
sudo yum -y install epel-release
sudo yum -y install python-contextlib2
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup


Ubuntu 16.04 or Debian GNU/Linux 8:
sudo apt-get -y update
sudo apt-get -y install g++ git cmake unzip bc python python-contextlib2 libtbb-dev libboost-dev zlib1g-dev libxt-dev libgstreamer1.0-dev libqt4-dev
  http://neuro.debian.net/install_pkg.html?p=fsl-complete
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup



For RHEL 7.x and CentOS 7.x (x86_64)
yum install epel-release
For RHEL 6.x and CentOS 6.x (x86_64)
rpm -ivh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
For RHEL 6.x and CentOS 6.x (i386)
rpm -ivh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm




sudo apt-get -y install qtdeclarative5-dev
sudo yum -y install qt5-qtdeclarative-devel


undefined reference to `vnl_vector<int>::operator=(vnl_vector
# qtdeclarative5-dev
qt5-qtdeclarative-devel


https://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py





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





FSLDIR=/usr/local/fsl
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLDIR PATH



overview table libraries/dependencies, links to licenses

discuss: libraries, setup packages, fsl, N4 care, path, licences



Run
------------
- A single subject pipeline can be run using the ./pipelines/dhcp-pipeline-v2.3.sh 
Running it without parameters will display the possible options.

- The run folder contains scripts for the execution within the dHCP file structure (main file: run/run.sh)
