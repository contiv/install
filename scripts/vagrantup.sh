#!/bin/bash

set -euo pipefail

num_nodes=${CONTIV_NODES:-2}
num_masters=${CONTIV_MASTERS:-1}
((num_workers = $num_nodes - $num_masters))

orc=$1
cd cluster
vagrant up $orc-master
for ((n = 1; n < $num_masters; n++)); do
	vagrant up $orc-master$n
done

for ((n = 0; n < $num_workers; n++)); do
	vagrant up $orc-worker$n
done
