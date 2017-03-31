#!/bin/bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "Please run this script as root user"
	exit 1
fi

apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
# Install docker if you don't have it already.
apt-get install -y docker.io
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
apt-get install -y ntp

systemctl enable ntpd && systemctl start ntpd
systemctl -q is-active firewalld && systemctl stop firewalld || true
systemctl -q is-enabled firewalld && systemctl disable firewalld || true

if systemctl -q is-active firewalld; then
	systemctl stop firewalld
fi
if systemctl -q is-enabled firewalld; then
	systemctl disable firewalld
fi
