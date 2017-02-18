# this is the classic first makefile target, and it's also the default target
# run when `make` is invoked with no specific target.
all: release

# release creates a release package for contiv.
# It uses a pre-built image specified by BUILD_VERSION.
release: 
	rm -rf release/
	@bash ./scripts/release.sh

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
# export BUILD_VERSION-1.0.0-beta.3
demo-k8s:
	CONTIV_KUBEADM=1 make cluster
	CONTIV_KUBEADM=1 make install-test-kubeadm

# demo-swarm brings up a cluster with docker swarm, runs the installer on it, and shows the URL
# of the demo Contiv Admin Console which was set up
# BUILD_VERSION must be setup to use a specific build, e.g.
# export BUILD_VERSION-1.0.0-beta.3
demo-swarm:
	make cluster
	make install-test-swarm

# Create a release and test the release installation on a vagrant cluster
# TODO: The vagrant part of this can be optimized by taking snapshots instead
# of creating a new set of VMs for each case
release-test-kubeadm: release 
	# Test kubeadm (centos by default)
	CONTIV_KUBEADM=1 make cluster
	CONTIV_KUBEADM=1 make install-test-kubeadm

release-test-swarm: release 
	# Test swarm (centos by default)
	make cluster
	make install-test-swarm

release-test-kubelegacy: release 
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
ci: release install-test-swarm install-test-kubeadm

.PHONY: all release cluster cluster-destroy release-test-swarm release-test-kubeadm release-test-kubelegacy install-test-swarm install-test-kubeadm install-test-kube-legacy
