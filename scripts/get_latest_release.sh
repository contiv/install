#!/bin/bash

set -euo pipefail

# Check if the user requested a specific build
if [[ ! -z "${BUILD_VERSION-}" ]]; then
	echo $BUILD_VERSION
	exit 0
fi

# Try to get the latest release
releases=$(curl -s https://api.github.com/repos/contiv/install/releases/latest)
if [[ "$releases" != *"browser_download_url"* ]]; then
	echo >&2 "failed to get latest release"
	exit 1
fi

release=$(echo "$releases" | python -c 'import json, sys; print(json.load(sys.stdin)["name"])')
echo $release

exit 0
