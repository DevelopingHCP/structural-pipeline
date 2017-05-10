# dHCP structural pipeline
==========================================

Installation
------------
Prerequisites:
- FSL
- VTK
- [MIRTK](https://github.com/BioMedIA/MIRTK) with DrawEM package ENABLED
- [SphericalMesh](https://gitlab.doc.ic.ac.uk/am411/SphericalMesh) package
- wb_command

cmake/make this package (dhcp-structural-pipeline)

Add the following binary dirs to the PATH (e.g. add to .bashrc file):
- export PATH=$PATH:< location of DRAWEM build bin directory >:< location of DRAWEM pipelines directory >
- export PATH=$PATH:< location of SPHERICALMESH build bin directory >
- export PATH=$PATH:< location of dhcp-structural-pipeline build bin directory >


Run
------------
- A single subject pipeline can be run using the ./pipelines/dhcp-pipeline-v2.3.sh 
Running it without parameters will display the possible options.

- The run folder contains scripts for the execution within the dHCP file structure (main file: run/run.sh)
