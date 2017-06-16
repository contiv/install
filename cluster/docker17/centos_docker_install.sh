#!/bin/bash

# This script installs Docker Swarm (Docker CE 17.03.1) on a node.
# Must be run locally on the node, as root (or with sudo).

set -euo pipefail

if [ $EUID -ne 0 ]; then
        echo "Please run this script as root user"
        exit 1
fi

# Install pre-reqs
yum makecache fast
yum install -y yum-utils device-mapper-persistent-data lvm2

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo


# Install Docker
# If you require a specific version, comment out the first line and uncomment 
# the other one. Fill in the version you want.
yum -y install docker-ce
#sudo yum install docker-ce-<VERSION>

# Post-install steps
# add admin user to docker group 
usermod -aG docker $SUDO_USER

# add /etc/docker/ if it doesn't exist
mkdir -p /etc/docker

# add (and create) daemon.json with entry for storage-device
cat <<EOT >> /etc/docker/daemon.json
{
  "storage-driver": "devicemapper"
}
EOT

# start up docker
systemctl enable docker
systemctl start docker

# TODO: REMOVE THIS ONCE THE Contiv Installer DOES THIS
# make sure /etc/openvswitch exists
mkdir -p /etc/openvswitch

exit 0
