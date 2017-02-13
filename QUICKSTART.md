# Quick Start Guide

This document provides the steps to create a quick setup on a local Mac OS or Linux host using a cluster of Virtual Box VMs setup using vagrant.

## Pre-requisites

* [Install Virtual Box 5.1.14 or later]( https://www.virtualbox.org/wiki/Downloads )
* [Install Vagrant 1.9.1 or later]( https://www.vagrantup.com/downloads.html )
* [Install Docker 1.12 or later]( https://docs.docker.com/engine/installation/ )
* Clone the Contiv install repository <br>
`git clone http://github.com/contiv/install'

## Setup the cluster with Contiv for Kubernetes
`make demo-k8s`

## Setup the cluster with Contiv for Docker with Swarm
`make demo-swarm`

## Customizing the setup

* The default configuration creates a 2 node cluster. To increase the number of nodes set the environment variable `CONTIV_NODES=<n>`

## Quick Start Guide for CentOS 7.x hosts

* Setup the pre-requisites as follows and follow the demo instructions above
```
 wget https://releases.hashicorp.com/vagrant/1.9.1/vagrant_1.9.1_x86_64.rpm
 wget http://download.virtualbox.org/virtualbox/5.1.14/VirtualBox-5.1-5.1.14_112924_el7-1.x86_64.rpm
 sudo yum install VirtualBox-5.1-5.1.14_112924_el7-1.x86_64.rpm -y
 sudo yum install vagrant_1.9.1_x86_64.rpm -y
 sudo yum install docker -y
 sudo systemctl start docker
 git clone http://github.com/contiv/install
```
