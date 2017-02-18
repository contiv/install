# Automated releases
TBD

# Manual releases
1. Set BUILD_VERSION, e.g., 1.0.0-beta.3. Set or update the following variables under script/build.sh. Merge via PR to appropriate branch.

	```
	auth_proxy_version=${CONTIV_API_PROXY_VERSION:-"1.0.0-beta.3"}
	aci_gw_version=${CONTIV_ACI_GW_VERSION:-"latest"}
	contiv_version=${CONTIV_VERSION:-"1.0.0-beta.3"}
	etcd_version=${CONTIV_ETCD_VERSION:-2.3.7}
	docker_version=${CONTIV_DOCKER_VERSION:-1.12.6}
	```

2. Build docker binary image. This would create a docker image contiv/install:$BUILD_VERSION.

	```
	make build
	```

2. Execute ```./scripts/release.sh``` Creates a new release on GitHub.

	```
	export GITHUB_USER=contiv
        export GITHUB_TOKEN=<your token here>
        ./scripts/release.sh
        ```

3. Push image to docker hub

	```
	docker login -u $docker_user -p $docker_password
	docker push contiv/install:$BUILD_VERSION
	```
