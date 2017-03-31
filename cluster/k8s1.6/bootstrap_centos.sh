#!/bin/bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
  echo "Please run this script as root user"   
  exit 1
fi

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://yum.kubernetes.io/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

setenforce 0

yum install -y docker kubelet kubeadm kubectl kubernetes-cni ntp

systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
systemctl enable ntpd && systemctl start ntpd

if systemctl -q is-active firewalld; then
	systemctl stop firewalld
fi
if systemctl -q is-enabled firewalld; then
	systemctl disable firewalld
fi
