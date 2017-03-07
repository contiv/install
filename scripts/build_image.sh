#!/bin/bash

set -euo pipefail
VERSION=${BUILD_VERSION-"latest"}

# Build the docker container for ansible installation
ansible_spec=./install/ansible/Dockerfile
docker build -t contiv/install:$VERSION -f $ansible_spec .

