#!/bin/bash

# Prepare k8s netplugin image
# * retrieves contiv/netplugin:$CONTIV_NETPLUGIN_VERSION from dockerhub
#
# or if $NETPLUGIN_BRANCH is set to an upstream branch name:
# * downloads the branch from fork owner $NETPLUGIN_OWNER and build k8s netplugin
#   image, export it as tarball

set -euxo pipefail

mkdir -p "$CONTIV_ARTIFACT_STAGING"

#### ENSURE contiv/netplugin:<tag> exists #####

if [ -z "${NETPLUGIN_BRANCH:-}" ]; then
	echo "Trying to use dockerhub contiv/netplugin:${CONTIV_NETPLUGIN_VERSION}"
	# ensure the image exists
	http_rc=$(curl -L -s -w "%{http_code}" -o /dev/null https://hub.docker.com/v2/repositories/contiv/netplugin/tags/${CONTIV_NETPLUGIN_VERSION}/)
	if [ "$http_rc" = 200 ]; then
		echo "Found contiv/netplugin:${CONTIV_NETPLUGIN_VERSION} on dockerhub, exit 0"
	else
		echo "Failed to find contiv/netplugin:${CONTIV_NETPLUGIN_VERSION} on dockerhub, return code $http_rc, exit 1"
		exit 1
	fi
else
	# tempdir for building and cleanup on exit
	netplugin_tmp_dir="$(mktemp -d)"
	trap 'rm -rf ${netplugin_tmp_dir}' EXIT

	echo Cloning ${NETPLUGIN_OWNER}/netplugin branch ${NETPLUGIN_BRANCH}
	# about 3x faster to pull the HEAD of a branch with no history
	git clone --branch ${NETPLUGIN_BRANCH} --depth 1 \
		https://github.com/${NETPLUGIN_OWNER}/netplugin.git \
		${netplugin_tmp_dir}/netplugin

	# Try to build docker image locally
	cd $netplugin_tmp_dir/netplugin
	make host-build-docker-image

	# the new built image tagged contivbase:latest
	# below codes probably should goto netplugin, here just a hacking way
	docker tag contivbase:latest contiv/netplugin:${CONTIV_NETPLUGIN_VERSION}
	docker save contiv/netplugin:${CONTIV_NETPLUGIN_VERSION} -o $CONTIV_ARTIFACT_STAGING/netplugin-image-${CONTIV_NETPLUGIN_VERSION}.tar
fi
#### ENSURE contiv/auth_proxy:<tag> exists #####

auth_proxy_version=${CONTIV_API_PROXY_VERSION:-$DEFAULT_DOWNLOAD_CONTIV_VERSION}

if [ -z "${NETPLUGIN_AUTH_PROXY_BRANCH:-}" ]; then
	echo "Trying to use dockerhub contiv/auth_proxy:${auth_proxy_version}"
	# ensure the image exists
	http_rc=$(curl -L -s -w "%{http_code}" -o /dev/null https://hub.docker.com/v2/repositories/contiv/auth_proxy/tags/${auth_proxy_version}/)
	if [ "$http_rc" = 200 ]; then
		echo "Found contiv/auth_proxy:${auth_proxy_version} on dockerhub, exit 0"
	else
		echo "Failed to find contiv/auth_proxy:${auth_proxy_version} on dockerhub, return code $http_rc, exit 1"
		exit 1
	fi
else
	# tempdir for building and cleanup on exit
	auth_proxy_tmp_dir="$(mktemp -d)"
	trap 'rm -rf ${auth_proxy_tmp_dir}' EXIT

	echo Cloning ${NETPLUGIN_AUTH_PROXY_OWNER}/auth_proxy branch ${NETPLUGIN_AUTH_PROXY_BRANCH}
	# about 3x faster to pull the HEAD of a branch with no history
	git clone --branch ${NETPLUGIN_AUTH_PROXY_BRANCH} --depth 1 \
		https://github.com/${NETPLUGIN_AUTH_PROXY_OWNER}/auth_proxy.git \
		${auth_proxy_tmp_dir}/auth_proxy

	# Try to build docker image locally
	cd $auth_proxy_tmp_dir/auth_proxy
	# this also checkouts contiv-ui master branch
	BUILD_VERSION=master make build
	# tag the same version with netplugin
	docker tag contiv/auth_proxy:master contiv/auth_proxy:${auth_proxy_version}
fi
