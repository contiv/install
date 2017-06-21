#!/bin/bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "Please run this script as root user"
	exit 1
fi

setenforce 0

yum install -y bzip2

yum install -y ntp
systemctl enable ntpd && systemctl start ntpd

if systemctl -q is-active firewalld; then
	systemctl stop firewalld
fi
if systemctl -q is-enabled firewalld; then
	systemctl disable firewalld
fi

exit 0
