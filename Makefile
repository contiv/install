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

# Brings up a demo cluster to install Contiv on - by default this is a docker, centos cluster.
# It can be configured to start a RHEL cluster by setting CONTIV_NODE_OS=rhel7.
# It can be started with k8s kubeadm install by running with CONTIV_KUBEADM=1.
cluster: cluster-destroy
	cd cluster && vagrant up

cluster-destroy:
	cd cluster && vagrant destroy -f

# demo-k8s brings up a cluster with k8s, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION=1.0.0-beta.3
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-k8s
demo-k8s:
	BUILD_VERSION=$(rel_ver) CONTIV_KUBEADM=1 make cluster
	BUILD_VERSION=$(rel_ver) CONTIV_KUBEADM=1 make install-test-kubeadm

# demo-swarm brings up a cluster with docker swarm, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION=1.0.0-beta.3
# Or run make as BUILD_VERSION=1.0.0-beta.3 make demo-k8s
demo-swarm:
	BUILD_VERSION=$(rel_ver) make cluster
	BUILD_VERSION=$(rel_ver) make install-test-swarm

# Create a build and test the release installation on a vagrant cluster
# TODO: The vagrant part of this can be optimized by taking snapshots instead
# of creating a new set of VMs for each case
release-test-kubeadm: build
	# Test kubeadm (centos by default)
	CONTIV_KUBEADM=1 make cluster
	CONTIV_KUBEADM=1 make install-test-kubeadm

release-test-swarm: build
	# Test swarm (centos by default)
	make cluster
	make install-test-swarm

release-test-kubelegacy: build
	# Test k8s ansible (centos by default)
	make cluster
	make install-test-kube-legacy 

# Test the installation on the provided cluster. This is for bare-metal and other
# setups where the cluster is created using non-vagrant mechanisms. 
# Clusters need to have k8s installed for kubernetes kubeadm based mechanism and
# docker installed on the master node for all others.
install-test-kubeadm:
	@bash ./scripts/kubeadm_test.sh

install-test-kube-legacy:
	@bash ./scripts/kube_legacy_test.sh

install-test-swarm:
	@bash ./scripts/swarm_test.sh

# ci does everything necessary for a Github PR-triggered CI run.
# currently, this means building a container image and running
# all of the available tests.
ci: build install-test-swarm install-test-kubeadm

.PHONY: all build cluster cluster-destroy release-test-swarm release-test-kubeadm release-test-kubelegacy install-test-swarm install-test-kubeadm install-test-kube-legacy
