# dHCP structural pipeline

![pipeline image](structural-pipeline.png)

The dHCP structural pipeline is a software for the structural analysis of the neonatal brain MRI (T1 and T2) that consists of:<br>
* cortical and sub-cortical volume segmentation
* cortical surface extraction (white matter and pial surface)
* cortical surface inflation and 
* projection to sphere.

## Publication
The pipeline is outlined in detail in:

A. Makropoulos and E. C. Robinson et al. "The Developing Human Connectome Project: a Minimal Processing Pipeline for Neonatal Cortical Surface Reconstruction (<a href="http://biorxiv.org/content/early/2017/04/07/125526">link</a>)


## License
The dHCP structural pipeline is distributed under the license outlined in LICENSE.txt


## Installation
The installation requires <b>FSL</b> and the <b>packages</b> specified in the <b>Dependencies</b> section.<br>
After installing these dependencies, the pipeline is installed by running:
* ./setup.sh -j [num_cores] 
<br>
where [num_cores] the number of CPU cores used to compile the pipeline software 
<br>

The setup script installs the following software packages.
   
| Software        | Version           
| ------------- |:-------------:|
| <a href="https://github.com/InsightSoftwareConsortium/ITK">ITK</a>      | 4.11.1 
| <a href="https://github.com/Kitware/VTK">VTK</a>      | 7.0.0     
| <a href="https://github.com/Washington-University/workbench">Connectome Workbench</a>  | 1.2.2  
| <a href="https://github.com/BioMedIA/MIRTK">MIRTK</a>  | 88c8266b016b465551d0bbafca9aed6340fdc1fb  
| <a href="https://gitlab.doc.ic.ac.uk/am411/SphericalMesh/">SphericalMesh</a>  | 0fb416cf88ba33e99df5e57b90281171f0f34005  

## Dependencies
#### 1. FSL
The dHCP structural pipeline uses the <b>FSL</b> software. This can be installed by following the instructions:

* Ubuntu (tested on version 16.04) / Debian GNU (tested on version 8): <br />
  http://neuro.debian.net/install_pkg.html?p=fsl-complete

* Mac OS X / Red Hat Enterprise Linux / CENTOS (tested on version 7): <br />
  https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation

The FSL software needs to be configured for <b>shell usage</b>:
* https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup

#### 2. Packages
The dHCP structural requires installation of the following packages.
#### Ubuntu (tested on version 16.04) / Debian GNU (tested on version 8):
* sudo apt-get -y update
* sudo apt-get -y install g++ git cmake unzip bc python python-contextlib2 libtbb-dev libboost-dev zlib1g-dev libxt-dev libgstreamer1.0-dev libqt4-dev

#### Mac OS X (tested on version 10.9.5):
* ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
* brew update
* brew install gcc git cmake unzip tbb boost cartr/qt4/qt
* sudo easy_install pip
* pip install contextlib2

#### Red Hat Enterprise Linux (tested on version 7.3):
* sudo yum -y update
* sudo yum -y install gcc-c++ git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel gstreamer1-devel
* curl -o epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
* sudo yum -y install epel.rpm
* sudo yum -y install python-contextlib2

#### CENTOS (tested on version 7):
* sudo yum -y update
* sudo yum -y install gcc-c++ git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel gstreamer1-devel 
* sudo yum -y install epel-release
* sudo yum -y install python-contextlib2

