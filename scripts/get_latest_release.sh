#!/bin/bash
# Check if the user requested a specific build
if [[ "$BUILD_VERSION" != "" ]]; then
	echo $BUILD_VERSION
	exit 0
fi

# Try to get the latest release
releases=$(curl -s https://api.github.com/repos/contiv/install/releases/latest)
if [[ "$releases" != *"browser_download_url"* ]]; then
	releases=$(curl -s https://api.github.com/repos/contiv/install/releases)
	if [[ "$releases" != *"browser_download_url"* ]]; then
		exit 1
	fi
	release=$(echo "$releases" | python -c 'import json, sys;print json.load(sys.stdin)[0]["name"]')
else
	release=$(echo "$releases" | python -c 'import json, sys;print json.load(sys.stdin)["name"]')
fi
echo $release
