# backwards compatibility name for CONTIV_INSTALLER_VERSION
export BUILD_VERSION ?= devbuild
# sets the version for the installer output artifacts
export CONTIV_INSTALLER_VERSION ?= $(BUILD_VERSION)
# downloaded and built assets intended to go in installer by build.sh
export CONTIV_ARTIFACT_STAGING := $(PWD)/artifact_staging
# some assets are retrieved from GitHub, this is the default version to fetch
export DEFAULT_DOWNLOAD_CONTIV_VERSION := 1.2.0
export CONTIV_ACI_GW_VERSION ?= latest
export NETPLUGIN_OWNER ?= contiv
# setting NETPLUGIN_BRANCH compiles that commit on demand,
# setting CONTIV_NETPLUGIN_VERSION will download that released version
ifeq ($(NETPLUGIN_BRANCH),)
export CONTIV_NETPLUGIN_VERSION ?= $(DEFAULT_DOWNLOAD_CONTIV_VERSION)
export CONTIV_V2PLUGIN_VERSION ?= $(DEFAULT_DOWNLOAD_CONTIV_VERSION)
else
export CONTIV_NETPLUGIN_VERSION := $(NETPLUGIN_OWNER)-$(NETPLUGIN_BRANCH)
export CONTIV_V2PLUGIN_VERSION ?= $(NETPLUGIN_OWNER)-$(NETPLUGIN_BRANCH)
endif
export CONTIV_NETPLUGIN_TARBALL_NAME := netplugin-$(CONTIV_NETPLUGIN_VERSION).tar.bz2
export CONTIV_ANSIBLE_COMMIT ?= 8e20f56d541af8bc7a3ecbde0d9c64fa943812ed
export CONTIV_ANSIBLE_OWNER ?= contiv
# TODO(chrisplo): restore the normal default after 1.1.8 has been pushed
#export CONTIV_ANSIBLE_IMAGE ?= contiv/install:$(DEFAULT_DOWNLOAD_CONTIV_VERSION)
export CONTIV_ANSIBLE_IMAGE ?= contiv/install:1.1.7-bash-netcat
export CONTIV_V2PLUGIN_TARBALL_NAME := v2plugin-$(CONTIV_V2PLUGIN_VERSION).tar.gz
export CONTIV_ANSIBLE_COMMIT ?= 00da7b2a1fd9f631bcfe283a0a640d903ca389f4
export CONTIV_ANSIBLE_OWNER ?= contiv

# this is the classic first makefile target, and it's also the default target
# run when `make` is invoked with no specific target.
all: build
rel_ver = $(shell ./scripts/get_latest_release.sh)

# accepts CONTIV_ANSIBLE_COMMIT and CONTIV_ANSIBLE_OWNER environment vars
download-ansible-repo:
	@scripts/download_ansible_repo.sh

# set NETPLUGIN_OWNER (default contiv) and NETPLUGIN_BRANCH make variables
# to compile locally
# e.g. make NETPLUGIN_OWNER=contiv NETPLUGIN_BRANCH=master
prepare-netplugin-artifacts:
	@./scripts/prepare_netplugin_artifacts.sh

assemble-build:
	@./scripts/build.sh

# build creates a release package for contiv.
# It uses a pre-built image specified by BUILD_VERSION.
build: download-ansible-repo prepare-netplugin-artifacts assemble-build

# ansible-image creates the docker image for ansible container
# It uses the version specified by BUILD_VERSION or creates an image with the latest tag.
ansible-image:
	@bash ./scripts/build_image.sh

# Brings up a demo cluster to install Contiv on with docker, centos.
cluster-legacy-swarm: vagrant-clean
	@bash ./scripts/vagrantup.sh legacy-swarm

# Brings up a demo cluster to install Contiv on with swarm, centos.
cluster-swarm-mode: vagrant-clean
	@bash ./scripts/vagrantup.sh swarm-mode

# Brings up a demo cluster to install Contiv on with kubeadm, centos.
cluster-kubeadm: vagrant-clean
	@bash ./scripts/vagrantup.sh kubeadm

cluster-destroy: vagrant-clean

# demo-swarm-mode brings up a cluster with native docker swarm, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION=1.0.0-beta.3
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-swarm-mode
demo-swarm-mode:
	BUILD_VERSION=$(rel_ver) make cluster-swarm-mode
	BUILD_VERSION=$(rel_ver) make install-test-swarm-mode

# demo-kubeadm brings up a cluster with kubeadm, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION=1.0.0-beta.3
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-kubeadm
demo-kubeadm:
	BUILD_VERSION=$(rel_ver) make cluster-kubeadm
	BUILD_VERSION=$(rel_ver) make install-test-kubeadm

# demo-swarm brings up a cluster with docker swarm, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION=1.0.0-beta.3
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-legacy-swarm
demo-legacy-swarm:
	BUILD_VERSION=$(rel_ver) make cluster-legacy-swarm
	BUILD_VERSION=$(rel_ver) make install-test-legacy-swarm

vagrant-clean:
	cd cluster && vagrant destroy -f
	@bash ./scripts/vbcleanup.sh

# Create a build and test the release installation on a vagrant cluster
# TODO: The vagrant part of this can be optimized by taking snapshots instead
# of creating a new set of VMs for each case
release-test-swarm-mode: build
	# Test swarm-mode (centos by default)
	make cluster-swarm-mode
	make install-test-swarm-mode

# create k8s release testing image (do not contains ansible)
k8s-build: prepare-netplugin-images assemble-build

prepare-netplugin-images:
	@bash ./scripts/prepare_netplugin_images.sh
# Create a build and test the release installation on a vagrant cluster
# TODO: The vagrant part of this can be optimized by taking snapshots instead
# of creating a new set of VMs for each case
release-test-kubeadm: k8s-build
	# Test kubeadm (centos by default)
	make cluster-kubeadm
	make install-test-kubeadm

release-test-legacy-swarm: build
	# Test docker + swarm (centos by default)
	make cluster-legacy-swarm
	make install-test-legacy-swarm

release-test-kubelegacy: build
	# Test k8s ansible (centos by default)
	make cluster-kubeadm
	make install-test-kube-legacy

# shfmt reformats all shell scripts in this repo
shfmt:
	go get github.com/contiv-experimental/sh/cmd/shfmt
	find . -type f -name "*.sh" -print0 | xargs -0 shfmt -w

# Test the installation on the provided cluster. This is for bare-metal and other
# setups where the cluster is created using non-vagrant mechanisms.
# Clusters need to have k8s installed for kubernetes kubeadm based mechanism and
# docker installed on the master node for all others.
install-test-swarm-mode:
	@bash ./scripts/swarm_mode_test.sh

install-test-kubeadm:
	@bash ./scripts/kubeadm_test.sh

install-test-kube-legacy:
	@bash ./scripts/kube_legacy_test.sh

install-test-legacy-swarm:
	@bash ./scripts/legacy_swarm_test.sh

# ci does everything necessary for a Github PR-triggered CI run.
# currently, this means building a container image and running
# all of the available tests.
ci: release-test-kubeadm
ci-old: release-test-swarm-mode release-test-kubeadm release-test-legacy-swarm

.PHONY: all build cluster cluster-destroy release-test-legacy-swarm release-test-swarm-mode release-test-kubeadm release-test-kubelegacy install-test-legacy-swarm install-test-swarm-mode install-test-kubeadm install-test-kube-legacy k8s-build prepare-netplugin-images
