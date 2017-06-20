#!/bin/bash

set -uo pipefail

vboxmanage list vms | grep -Ff <(cd cluster && vagrant status | grep "running" | awk '{print $1}') | awk -F '"' '{print $2}' | xargs -I {} vboxmanage controlvm {} poweroff
vboxmanage list vms | grep -Ff <(cd cluster && vagrant status | grep "poweroff" | awk '{print $1}') | awk -F '"' '{print $2}' | xargs -I {} vboxmanage unregistervm --delete {}
vagrant global-status --prune
exit 0