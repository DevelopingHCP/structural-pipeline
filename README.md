# dHCP structural pipeline
==========================================

Installation
------------
Prerequisites:
- FSL


Dependencies
------------


Red Hat Enterprise Linux RHEL-7.3:
sudo yum update
sudo yum -y install gcc-c++ git cmake unzip
sudo yum -y install qt-devel tbb-devel boost-devel

openssl qt qt-devel
cmake tbb tbb-devel boost boost-devel
curl wget





Ubuntu 16.04 or Debian GNU/Linux 8:
sudo apt-get update

sudo apt-get -y install g++ git cmake unzip
sudo apt-get -y install libtbb-dev libboost-dev libqt4-dev zlib1g-dev
qtdeclarative5-dev


git clone https://gitlab.doc.ic.ac.uk/am411/structural-pipeline.git
cd structural-pipeline
./setup.sh -j 7





overview table libraries/dependencies, links to licenses

discuss: libraries, setup packages, fsl, N4 care, path, licences



Run
------------
- A single subject pipeline can be run using the ./pipelines/dhcp-pipeline-v2.3.sh 
Running it without parameters will display the possible options.

- The run folder contains scripts for the execution within the dHCP file structure (main file: run/run.sh)
