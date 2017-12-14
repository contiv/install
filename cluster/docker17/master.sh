docker swarm init --advertise-addr $1
docker swarm join-token manager |
	grep -A 20 "docker swarm join" >$2/manager.sh
docker swarm join-token worker |
	grep -A 20 "docker swarm join" >$2/worker.sh
