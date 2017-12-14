#!/bin/bash

# Will look for full installer, else the smaller installer, else download
# the installer and unpack it.  Assumes "devbuild" unless BUILD_VERSION
# is set
# 'BUILD_VERSION=1.2.3 unpack-installer.sh' looks for:
#  - contiv-full-1.2.3.tgz
#  - contiv-1.2.3.tgz
#  - https://github.com/contiv/install/releases/download/1.2.3/contiv-1.2.3.tgz

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p release
cd release

#################################
# Extract the installer
#################################

# If BUILD_VERSION is not defined, assume "devbuild" which presumably was
# created with make BUILD_VERSION=devbuild
BUILD_VERSION="${BUILD_VERSION:-devbuild}"
release_name="contiv-${BUILD_VERSION}"

rm -rf ${release_name}

# this tarball has a cache of binary assets
release_tarball="contiv-full-${BUILD_VERSION}.tgz"
if [ ! -f "${release_tarball}" ]; then
	release_tarball="${release_name}.tgz"
fi
if [ ! -f "${release_tarball}" ]; then
	# For release builds, get the build from github releases
	echo Downloading ${release_tarball} from GitHub releases
	curl --fail -L -O https://github.com/contiv/install/releases/download/${BUILD_VERSION}/${release_tarball}
fi

echo Unpacking ${release_tarball}
tar -zoxf "${release_tarball}"
