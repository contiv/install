#!/bin/bash

# Try to get the latest release
url=$(curl -s https://api.github.com/repos/contiv/install/releases/latest  | grep -m 1 "browser_download_url")

if [[ "$?" != "0" ]]; then
  url=$(curl -s https://api.github.com/repos/contiv/install/releases  | grep -m 1 "browser_download_url")
  if [[ "$?" != "0" ]]; then
  	exit 1
  fi
fi
release=$(echo $url | awk -F "/" '{print $8}')
echo $release
