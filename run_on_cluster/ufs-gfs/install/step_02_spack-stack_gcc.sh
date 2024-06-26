#! /bin/bash
#=====================================
# Install spack-stack for use with UFS
#
# Run this script in a gcc-toolset-11
# enabled bash shell to access gcc11,
# i.e.:
#
# scl enable gcc-toolset-11 bash
# ./step_02_spack-stack.sh
#
# Based on the instructions at:
# https://spack-stack.readthedocs.io/en/latest/NewSiteConfigs.html#newsiteconfigs-linux
#=====================================

# Select gcc compiler to use
gcc_ver=11
source /opt/rh/gcc-toolset-${gcc_ver}/enable

# Download Spack, start it, and add the buildcache
# mirror to Spack.

#==========================================
# Step 1: Where do you want to put Spack?

# Default location for spack-stack?
#spack_dir=/contrib/spack-stack/spack-stack-1.6.0

# Try $HOME for now...
spack_dir=${HOME}/spack

#===========================================
# Step 2: Grab Spack

mkdir -p $spack_dir
cd $spack_dir

# Standard spack
#git clone -c feature.manyFiles=true https://github.com/spack/spack.git
# source ${PWD}/spack/share/spack/setup-env.sh

# JCSDA spack-stack, UFS is probably at 1.5.1
git clone --recurse-submodules -b spack-stack-1.5.1 https://github.com/jcsda/spack-stack.git
cd spack-stack
# Sources Spack from submodule and sets ${SPACK_STACK_DIR}
source setup.sh

#==========================================
# Step 3: Connect to a buildcache
# Note that here we assume you have already exported
# your cloud bucket credentials into environment
# variables to use a bucket-based buildcache.
# You can replace the s3:// URL here with a path
# if using an attached storage based buildcache.
spack mirror add ufs-cache s3://$BUCKET_NAME
spack compiler find
spack buildcache list

#=========================================
# Step 4: Create a Spack environment based
# on the existing template provided by
# spack-stack.

# Very out of date?
#template_name="gfs-v16.2"

# Runs, but incomplete
#template_name="ufs-weather-model"

# Try everything
template_name="unified-dev"
spack stack create env --site linux.default --template ${template_name} --name ${template_name}.mylinux
cd envs/${template_name}.mylinux/
spack env activate -p .

#=========================================
# Step 5: Find external packages
# Use SPACK_SYSTEM_CONFIG_PATH to modify site config
# files in envs/${template_name}.mylinux/site
export SPACK_SYSTEM_CONFIG_PATH="$PWD/site"

spack external find --scope system \
    --exclude bison --exclude cmake \
    --exclude curl --exclude openssl \
    --exclude openssh --exclude python

spack external find --scope system wget

# Note - only needed for running JCSDA's
# JEDI-Skylab system (using R2D2 localhost)
spack external find --scope system mysql

# Note - only needed for generating documentation
spack external find --scope system texlive

spack compiler find --scope system

# Done finding external packages, so unset
unset SPACK_SYSTEM_CONFIG_PATH

# Set default compiler and MPI library
spack config add "packages:all:compiler:[gcc@11.2.1]"
spack config add "packages:all:providers:mpi:[openmpi]"

# Set a few more package variants and versions 
# to avoid linker errors and duplicate packages 
# being built
spack config add "packages:fontconfig:variants:+pic"
spack config add "packages:pixman:variants:+pic"
spack config add "packages:cairo:variants:+pic"

# For JCSDA's JEDI-Skylab experiments using 
# R2D2 with a local MySQL server:
#spack config add "packages:ewok-env:variants:+mysql"

#=====================================
# Step 6: Process the specs and install
# Save the output of concretize in a log file
# so you can inspect that log with show_duplicate_packages.py.
# Duplicate package specifications can cause 
# issues in the module creation step below. 
spack concretize 2>&1 | tee log.concretize
${SPACK_STACK_DIR}/util/show_duplicate_packages.py -d -c log.concretize
spack install --no-check-signature --verbose --fail-fast 2>&1 | tee log.install

# Create tcl module files (replace tcl with lmod?)
spack module tcl refresh -y

# Create meta-modules for compiler, MPI, Python
spack stack setup-meta-modules

echo "You now have a spack-stack environment" 
echo "that can be accessed by running:"
echo "module use ${SPACK_STACK_DIR}/envs/${template_name}.mylinux/install/modulefiles/Core"
echo "The modules defined here can be loaded" 
echo "to build and run code as described at: "
echo "https://spack-stack.readthedocs.io/en/latest/UsingSpackEnvironments.html#usingspackenvironments"
echo "This script was based on the Linux instructions at: "
echo "https://spack-stack.readthedocs.io/en/latest/NewSiteConfigs.html#newsiteconfigs-linux"

