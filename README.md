# dHCP structural pipeline
==========================================

Installation
------------
Prerequisites:
- FSL


Dependencies
------------
gcc-c++ git


openssl qt qt-devel
cmake tbb tbb-devel boost boost-devel
curl wget


sudo apt-get install g++ git cmake unzip
sudo apt-get install libtbb-dev libboost-dev qtdeclarative5-dev


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
