# Automated releases
TBD

# Manual releases
1. Check out the right branch and the right commit. This is necessary
when not releasing from the HEAD of master.

2. Tag the right commit and push it to GitHub. This is mandatory if the
release isn't made from the HEAD of master.
	```
	git tag 1.0.1 3aba546aea1235
	git push origin 1.0.1
	```

3. Set BUILD_VERSION, e.g., 1.0.0-beta.3. Set or update the following variables under script/build.sh. Merge via PR to appropriate branch.

	```
	auth_proxy_version=${CONTIV_API_PROXY_VERSION:-"1.0.0-beta.3"}
	aci_gw_version=${CONTIV_ACI_GW_VERSION:-"latest"}
	contiv_version=${CONTIV_VERSION:-"1.0.0-beta.3"}
	etcd_version=${CONTIV_ETCD_VERSION:-v2.3.8}
	docker_version=${CONTIV_DOCKER_VERSION:-1.12.6}
	```

4. Build docker binary image. This would create a docker image contiv/install:$BUILD_VERSION. It also creates two release bundles - contiv-${BUILD_VETSION}.tgz and contiv-full-${BUILD_VERSION}.tgz. This version should be tested locally using a vagrant setup with release-test-* make targets.

	```
	make ansible-image
	```

5. Execute ```./scripts/release.sh``` Creates a new release on GitHub.

	```
	export GITHUB_USER=contiv
        export GITHUB_TOKEN=<your token here>
        ./scripts/release.sh
        ```

6. Push image to docker hub

	```
	docker login -u $docker_user -p $docker_password
	docker push contiv/install:$BUILD_VERSION
	```
