# this is the classic first makefile target, and it's also the default target
# run when `make` is invoked with no specific target.
all: build
rel_ver = $(shell ./scripts/get_latest_release.sh)

# build creates a release package for contiv.
# It uses a pre-built image specified by BUILD_VERSION.
build:
	rm -rf release/
	@bash ./scripts/build.sh

# ansible-image creates the docker image for ansible container
# It uses the version specified by BUILD_VERSION or creates an image with the latest tag.
ansible-image:
	@bash ./scripts/build_image.sh

# Brings up a demo cluster to install Contiv on with docker, centos.
cluster-legacy-swarm: vagrant-clean
	cd cluster && \
	vagrant up legacy-swarm-master && \
	vagrant up legacy-swarm-worker0

# Brings up a demo cluster to install Contiv on with swarm, centos.
cluster-swarm-mode: vagrant-clean	
	cd cluster && \
	vagrant up swarm-mode-master && \
	vagrant up swarm-mode-worker0

# Brings up a demo cluster to install Contiv on with kubeadm, centos.
cluster-kubeadm: vagrant-clean
	cd cluster && \
	vagrant up kubeadm-master && \
	vagrant up kubeadm-worker0

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
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-k8s
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

# Create a build and test the release installation on a vagrant cluster
# TODO: The vagrant part of this can be optimized by taking snapshots instead
# of creating a new set of VMs for each case
release-test-kubeadm: build
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
	go get github.com/mvdan/sh/cmd/shfmt
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
ci: release-test-swarm-mode release-test-kubeadm release-test-legacy-swarm

.PHONY: all build cluster cluster-destroy release-test-legacy-swarm release-test-swarm-mode release-test-kubeadm release-test-kubelegacy install-test-legacy-swarm install-test-swarm-mode install-test-kubeadm install-test-kube-legacy
