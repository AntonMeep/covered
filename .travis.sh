#!/bin/bash

set -e

if [ "$DC" != gdc ]; then
	dub test --compiler=$DC
fi

echo "Building $(git tag -l --points-at HEAD) for $TRAVIS_OS_NAME x86_64 using $DC"
dub build -b release --compiler=$DC
tar -zcf "covered-$(git tag -l --points-at HEAD)-$TRAVIS_OS_NAME-$DC-x86_64.tar.gz" covered
