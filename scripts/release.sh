#!/bin/bash
# Assumes following variables to be defined:
#  OLD_VERSION - previous version against which to create changelog
#  BUILD_VERSION - new version being released
#  GITHUB_USER - contiv
#  GITHUB_TOKEN - your github token
#  USE_RELEASE - if 0 or not set, will make a pre-release

cd -P -- "$(dirname -- "$0")"

# Install github-release binary if not present
if [ -z "$(which github-release)" ]; then
	go get -u github.com/aktau/github-release || exit 1
fi

if [ -z "$BUILD_VERSION" ]; then
	echo "A release requires BUILD_VERSION to be defined"
	exit 1
fi

if [ -z "$OLD_VERSION" ]; then
	echo "A release requires OLD_VERSION to be defined"
	exit 1
fi

if [ "$OLD_VERSION" != "none" ]; then
	comparison="$OLD_VERSION..HEAD"
fi

if [ "$USE_RELEASE" != "1" ]; then
	echo "Making a pre-release..."
	pre_release="-p"
fi

if [ "$OLD_VERSION" != "none" ]; then
	changelog=$(git log $comparison --oneline --no-merges --reverse)

	if [ -z "$changelog" ]; then
		echo "No new changes to release!"
		exit 0
	fi
else
	changelog="don't forget to update the changelog"
fi

TAR_FILENAME="contiv-"${BUILD_VERSION}".tgz"
TAR_FILENAME2="contiv-full-"${BUILD_VERSION}".tgz"
TAR_FILE="../release/contiv-"${BUILD_VERSION}".tgz"
TAR_FILE2="../release/contiv-full-"${BUILD_VERSION}".tgz"
if [ ! -f ${TAR_FILE} ] || [ ! -f ${TAR_FILE2} ]; then
	echo "release file(s) does not exist"
	exit 1
fi

set -x
( (github-release -v release $pre_release -r install -t $BUILD_VERSION -d "**Changelog**<br/>$changelog") &&
	( (github-release -v upload -r install -t $BUILD_VERSION -n $TAR_FILENAME -f $TAR_FILE &&
		github-release -v upload -r install -t $BUILD_VERSION -n $TAR_FILENAME2 -f $TAR_FILE2) ||
		github-release -v delete -r install -t $BUILD_VERSION)) || exit 1
