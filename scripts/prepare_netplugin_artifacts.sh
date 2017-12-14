#!/bin/bash

# Produces a tarball of netplugin binaries at $CONTIV_ARTIFACT_STAGING
# It either:
# * retrieves netplugin-$CONTIV_NETPLUGIN_VERSION.tar.bz2 from github
#   releases
# or if $NETPLUGIN_BRANCH is set to an upstream branch name:
# * downloads the branch from fork owner $NETPLUGIN_OWNER and compiles
#   it, naming it netplugin-<COMMIT_SHA>.tar.bz2

set -euxo pipefail

: ${CONTIV_NETPLUGIN_TARBALL_NAME} # check if defined

mkdir -p "$CONTIV_ARTIFACT_STAGING"

# check if installer is for a release version of netplugin
if [ -z "${NETPLUGIN_BRANCH:-}" ]; then
	echo Downloading netplugin-${CONTIV_NETPLUGIN_VERSION}
	# retrieve release vesion of netplugin
	base_url=https://github.com/contiv/netplugin/releases/download
	netplugin_bundle_name=netplugin-$CONTIV_NETPLUGIN_VERSION.tar.bz2
	curl -sL ${base_url}/$CONTIV_NETPLUGIN_VERSION/$netplugin_bundle_name \
		-o "${CONTIV_ARTIFACT_STAGING}/$netplugin_bundle_name"
	exit
fi

# build netplugin based on SHA

# tempdir for building and cleanup on exit
netplugin_tmp_dir="$(mktemp -d)"
trap 'rm -rf ${netplugin_tmp_dir}' EXIT

echo Cloning ${NETPLUGIN_OWNER}/netplugin branch ${NETPLUGIN_BRANCH}
# about 3x faster to pull the HEAD of a branch with no history
git clone --branch ${NETPLUGIN_BRANCH} --depth 1 \
	https://github.com/${NETPLUGIN_OWNER}/netplugin.git \
	${netplugin_tmp_dir}/netplugin

# run the build and extract the binaries
cd $netplugin_tmp_dir/netplugin
# BUILD_VERSION (currently == devbuild) is in env, so clear it
declare +x BUILD_VERSION
# this is most likely to be just SHA because we pulled only single commit
NETPLUGIN_VERSION=$(./scripts/getGitVersion.sh)
BUILD_VERSION=${NETPLUGIN_VERSION} make tar host-pluginfs-create

# move the netplugin tarball to the staging directory for the installer
mv netplugin-${NETPLUGIN_VERSION}.tar.bz2 "${CONTIV_ARTIFACT_STAGING}/"
# move the v2plugin tarball to the staging directory for the installer
mv install/v2plugin/v2plugin-${NETPLUGIN_VERSION}.tar.gz "${CONTIV_ARTIFACT_STAGING}/"
# copy the container's config.json needed to create the v2plugin
cp install/v2plugin/config.json "${CONTIV_ARTIFACT_STAGING}/"

# create links so other scripts can find the archives without knowing the SHA
cd "${CONTIV_ARTIFACT_STAGING}"
ln -sf netplugin-${NETPLUGIN_VERSION}.tar.bz2 $CONTIV_NETPLUGIN_TARBALL_NAME
ln -sf v2plugin-${NETPLUGIN_VERSION}.tar.gz $CONTIV_V2PLUGIN_TARBALL_NAME
