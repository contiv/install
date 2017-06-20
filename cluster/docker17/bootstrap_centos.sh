#!/bin/bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "Please run this script as root user"
	exit 1
fi

yum install -y yum-utils
yum-config-manager \
      --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo

yum makecache fast
yum -y install docker-ce

setenforce 0

yum install -y ntp

systemctl enable docker && systemctl start docker
systemctl enable ntpd && systemctl start ntpd

if systemctl -q is-active firewalld; then
	systemctl stop firewalld
fi
if systemctl -q is-enabled firewalld; then
	systemctl disable firewalld
fi
usermod -a -G docker $SUDO_USER

exit 0
