# dHCP Structural Pipeline v1.1

![pipeline image](structural_pipeline.png)

The dHCP structural pipeline is a software for the structural analysis of the neonatal brain MRI (T1 and T2) that consists of:<br>
* cortical and sub-cortical volume segmentation
* cortical surface extraction (white matter and pial surface)
* cortical surface inflation and 
* projection to sphere

## Publication
The pipeline is described in detail in:

A. Makropoulos and E. C. Robinson et al. "The Developing Human Connectome Project: a Minimal Processing Pipeline for Neonatal Cortical Surface Reconstruction (<a href="http://biorxiv.org/content/early/2017/04/07/125526">link</a>)

## Developers
<b>Antonios Makropoulos</b>: main author, development of the structural pipeline, and segmentation software <a href="http://antoniosmakropoulos.com">more</a>

<b>Andreas Schuh</b>: contributor, development of the cortical surface extraction, and surface inflation software <a href="http://andreasschuh.com">more</a>

<b>Robert Wright</b>: contributor, development of the spherical projection software

## License
The dHCP structural pipeline is distributed under the terms outlined in LICENSE.txt

## Install and run with docker
You can build the pipeline in a docker container. This will work on any
version of any platform, is automated, and fairly simple. First, install
docker:

https://docs.docker.com/engine/installation/

Then in the top directory of `structural-pipeline`, use git to switch to the
branch you want to build, and enter:

```
# docker build -t <user>/structural-pipeline:latest .
```

Substituting `<user>` for your username. This command must be run as root. 

This will create a single docker image called
`<user>/structural-pipeline:latest` containing all the required files 
and all required dependencies. 

You can then execute the pipeline like this (for example):

```
# docker run --rm -t -v $PWD/data:/data \
    <user>/structural-pipeline:latest \
    bash -c ". /etc/fsl/fsl.sh; \
        cd /usr/src/structural-pipeline; \
        ./dhcp-pipeline.sh subject1 session1 44 \
            -d /data -T2 /data/sub-CC00183XX11_ses-60300_T2w.nii.gz -t 8"
```

Again, this must be run as root. This will mount the subdirectory `data` of
your current directory as `/data` in the container, then execute the pipeline
on the file `sub-CC00183XX11_ses-60300_T2w.nii.gz`. The output files will be
written to your `data` subdirectory. 

## Run interactively
Handy for debugging:

```
# sudo docker run \
    -v /home/john/pics/dhcp/data:/data \
    -it john/structural-pipeline:latest /bin/bash
```

## Install locally
If you want to work on the code of the pipeline, it can be more convenient to
install locally to your machine. Only read on if you need to do a local
install. 

## Dependencies
#### 1. FSL
The dHCP structural pipeline uses the <b>FSL</b> software. This can be installed by following the instructions:

<details>
<summary> <b>Ubuntu / Debian GNU</b></summary>

http://neuro.debian.net/install_pkg.html?p=fsl-complete
  
</details>

<details>
<summary> <b>Mac OS X / Red Hat Enterprise Linux / CENTOS</b></summary>

https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
  
</details>
<br>
The FSL software needs to be configured for <b>shell usage</b>:

* https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/ShellSetup

#### 2. Packages
The dHCP structural requires installation of the following packages.

<details>
<summary> <b>Mac OS X (tested on version 10.9.5)</b></summary>

* \# install brew if needed with the following command:
* ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
* brew update
* brew install gcc5 git cmake unzip tbb boost expat cartr/qt4/qt
* sudo easy_install pip
* pip install contextlib2

</details>


<details>
<summary> <b>Ubuntu (tested on version 16.04)</b></summary>

* sudo apt-get -y update
* sudo apt-get -y install g++-5 git cmake unzip bc python python-contextlib2 libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev libgstreamer1.0-dev libqt4-dev

</details>

<details>
<summary> <b>Debian GNU (tested on version 8)</b></summary>

* sudo apt-get -y update
* sudo apt-get -y install git cmake unzip bc python python-contextlib2 libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev libgstreamer1.0-dev libqt4-d
* \# g++-5 is not in the default packages of Debian, install with the following commands:
* echo "deb http://ftp.us.debian.org/debian unstable main contrib non-free" | sudo tee -a /etc/apt/sources.list
* sudo apt-get -y update
* sudo apt-get -y install g++-5

</details>

<details>
<summary> <b>CENTOS (tested on version 7)</b></summary>

* sudo yum -y update
* sudo yum -y install git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel expat-devel gstreamer1-devel 
* sudo yum -y install epel-release
* sudo yum -y install python-contextlib2
* \# g++-5 is not in the default packages of CENTOS, install with the following commands:
* sudo yum -y install centos-release-scl
* sudo yum -y install devtoolset-4-gcc*
* \# then activate it at the terminal before running the installation script
* scl enable devtoolset-4 bash

</details>

<details>
<summary> <b>Red Hat Enterprise Linux (tested on version 7.3)</b></summary>

* sudo yum -y update
* sudo yum -y install it cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel expat-devel gstreamer1-devel
* \# the epel-release-latest-7.noarch.rpm is for version 7 of RHEL, this needs to be adjusted for the user's OS version
* curl -o epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
* sudo yum -y install epel.rpm
* sudo yum -y install python-contextlib2
* \# g++-5 is not in the default packages of RHEL, install with the following commands:
* sudo yum-config-manager --enable rhel-server-rhscl-7-rpms
* sudo yum -y install devtoolset-4-gcc*
* \# then activate it at the terminal before running the installation script
* scl enable devtoolset-4 bash

</details>

## Installation
The installation requires <b>FSL</b> and the <b>packages</b> specified in the <b>Dependencies</b> section.<br>
After installing these dependencies, the pipeline is installed by running:
* ./setup.sh -j [num_cores] 

where [num_cores] the number of CPU cores used to compile the pipeline software 
<br>

The setup script installs the following software packages.
   
| Software        | Version           
| ------------- |:-------------:|
| <a href="https://github.com/InsightSoftwareConsortium/ITK">ITK</a>      | 4.11.1 
| <a href="https://github.com/Kitware/VTK">VTK</a>      | 7.0.0     
| <a href="https://github.com/Washington-University/workbench">Connectome Workbench</a>  | 1.2.2  
| <a href="https://github.com/BioMedIA/MIRTK">MIRTK</a>  | dhcp-v1
| <a href="https://github.com/amakropoulos/SphericalMesh">SphericalMesh</a>  | dhcp-v1.1

The '-h' argument can be specified to provide more setup options:
* ./setup.sh -h

Once the installation is successfully completed, if desired, the different commands/tools built (workbench, MIRTK and pipeline commands) can be included in the shell PATH by running:
* . parameters/path.sh


## Run

The pipeline can be run with the following command:

./dhcp-pipeline.sh [subject_ID] [session_ID] [scan_age] -T2 [T2_image] \( -T1 [T1_image] \) \( -t [num_threads] \)

where:

| Argument        | Type      | Description     
| ------------- |:-------------:| :-------------:|
| subject_ID| string | Subject ID
| session_ID| string | Session ID
| scan_age| double |Subject post-menstrual age (PMA) in weeks (number between 28-44). <br>If the age is <28w or >44w, it will be set to 28w or 44w respectively.
| T2_image| nifti image | The T2 image of the subject
| T1_image| nifti image |The T1 image of the subject (Optional)
| num_threads| integer |Number of threads (CPU cores) used (default: 1) (Optional)

Examples:
* ./dhcp-pipeline.sh subject1 session1 44 -T2 subject1-T2.nii.gz -T1 subject1-T1.nii.gz -t 8
* ./dhcp-pipeline.sh subject2 session1 36 -T2 subject2-T2.nii.gz -T1 subject2-T1.nii.gz 
* ./dhcp-pipeline.sh subject3 session4 28 -T2 subject3-T2.nii.gz 

The output of the pipeline is the following directories:
* sourcedata   : folder containing the source images (T1,T2) of the processed subjects
* derivatives  : folder containing the output of the pipeline processing

Measurements and reporting for the dHCP Structural Pipeline can be additionally computed using this <a href="https://github.com/amakropoulos/structural-pipeline-measures">package</a>.

