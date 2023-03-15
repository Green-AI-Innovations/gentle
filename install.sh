#!/bin/bash

set -e

# Check if the script is run from the gentle folder
if [ "$(basename $(pwd))" != "gentle" ]; then
    echo "Error: This script must be run from the 'gentle' folder"
    exit 1
fi

# Initialize and update the submodules (Kaldi and its dependencies)
git submodule update --init --recursive

# Set the paths
GENTLE_ROOT=$(pwd)
GENTLE_EXT_DIR="$GENTLE_ROOT/ext"
KALDI_ROOT="$GENTLE_EXT_DIR/kaldi"
KALDI_TOOLS_DIR="$KALDI_ROOT/tools"
KALDI_TOOLS_EXTRAS_DIR="$KALDI_TOOLS_DIR/extras"
KALDI_SRC_DIR="$KALDI_ROOT/src"

# Define the directories to check
dirs_to_check=(
    "$GENTLE_ROOT"
    "$GENTLE_EXT_DIR"
    "$KALDI_ROOT"
    "$KALDI_TOOLS_DIR"
    "$KALDI_SRC_DIR"
    "$KALDI_TOOLS_EXTRAS_DIR"
)

# Check if the directories exist
for dir in "${dirs_to_check[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Error: Directory $dir does not exist. This script must be run from the 'gentle' folder"
        exit 1
    fi
done

# Define a function to clean up the symbolic link the Kaldi check dependencies script creates
cleanup() {
    echo "Removing the symbolic link to the Python executable created by Kaldi's check dependencies script"
    rm -f "$GENTLE_ROOT/python/python"
}

# Register the cleanup function to be called when the script receives a signal
trap cleanup EXIT

# Remove the symbolic link if it exists
cleanup

# Check system-level dependencies first, see `ext/kaldi/tools/INSTALL` for more details
echo "Entering $KALDI_TOOLS_EXTRAS_DIR"
pushd $KALDI_TOOLS_EXTRAS_DIR >/dev/null
./check_dependencies.sh
echo "Leaving $KALDI_TOOLS_EXTRAS_DIR"
popd >/dev/null
# Exit with status code 1 if `check_dependencies.sh` returns a non-zero status code
if [ $? -ne 0 ]; then
    echo "System-level dependencies are not satisfied. Please install them first. Look at the output above for more details"
    exit 1
fi

# Install Kaldi's essential tools
echo "Entering $KALDI_TOOLS_DIR"
pushd $KALDI_TOOLS_DIR >/dev/null
echo "Installing essential dependencies for Kaldi's tools"
make -j $(nproc) -w -s
echo "Leaving $KALDI_TOOLS_DIR"
popd >/dev/null

# Install OpenBLAS
echo "Entering $KALDI_TOOLS_EXTRAS_DIR"
pushd $KALDI_TOOLS_EXTRAS_DIR >/dev/null
export MAKEFLAGS="-j $(nproc) -w -s"
echo "Installing OpenBLAS"
./install_openblas.sh
unset MAKEFLAGS
echo "Leaving $KALDI_TOOLS_EXTRAS_DIR"
popd >/dev/null

# Configure Kaldi installation
echo "Entering $KALDI_SRC_DIR"
pushd $KALDI_SRC_DIR >/dev/null
echo "Configuring Kaldi installation"
OPENBLAS_INSTALL_PATH="$KALDI_TOOLS_EXTRAS_DIR/OpenBLAS/install"
./configure --static --static-math=yes --static-fst=yes --use-cuda=no --openblas-root=$OPENBLAS_INSTALL_PATH
echo "Leaving $KALDI_SRC_DIR"
popd >/dev/null

# Install necessary Gentle models
echo "Entering $GENTLE_ROOT"
pushd $GENTLE_ROOT >/dev/null
echo "Installing necessary Gentle models"
yes | ./install_models.sh
echo "Leaving $GENTLE_ROOT"
popd >/dev/null

# Generate dependencies for Kaldi source code
echo "Entering $KALDI_SRC_DIR"
pushd $KALDI_SRC_DIR >/dev/null
echo "Generating dependencies for Kaldi source code"
make -j $(nproc) -w -s depend
echo "Leaving $KALDI_SRC_DIR"
popd >/dev/null

# Compile Kaldi and Gentle
echo "Entering $GENTLE_EXT_DIR"
pushd $GENTLE_EXT_DIR >/dev/null
echo "Compiling Kaldi and Gentle"
make -j $(nproc) -w -s
echo "Leaving $GENTLE_EXT_DIR"
popd >/dev/null

# Clean up build artifacts
echo "Entering $GENTLE_ROOT"
pushd $GENTLE_ROOT >/dev/null
echo "Cleaning up build artifacts"
find $GENTLE_ROOT -type f \( -name "*.o" -o -name "*.la" -o -name "*.a" \) -exec rm {} \;
echo "Leaving $GENTLE_ROOT"
popd >/dev/null
