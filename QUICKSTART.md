# Quick Start Guide

Please follow the tutorials [here](http://contiv.github.io/documents/tutorials/).

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
