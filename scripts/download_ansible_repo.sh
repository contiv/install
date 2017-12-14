#!/bin/bash

set -euo pipefail

ANSIBLE_REPO_DIR="${CONTIV_ARTIFACT_STAGING}/ansible"

rm -rf "$ANSIBLE_REPO_DIR"

mkdir -p "$ANSIBLE_REPO_DIR" "$CONTIV_ARTIFACT_STAGING"

echo downloading ${CONTIV_ANSIBLE_OWNER}/ansible commit: $CONTIV_ANSIBLE_COMMIT
curl --fail -sL https://api.github.com/repos/${CONTIV_ANSIBLE_OWNER}/ansible/tarball/$CONTIV_ANSIBLE_COMMIT |
	tar --strip-components 1 -C "$ANSIBLE_REPO_DIR" -z -x
