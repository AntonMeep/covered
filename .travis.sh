#!/bin/bash

dub test --compiler=$DC

if [ "$DC" == ldc2 ] && [ -n "$TRAVIS_TAG" ]; then
	echo "Building $TRAVIS_TAG for $TRAVIS_OS_NAME x86_64"
	dub build -b release --compiler=$DC
	tar -zcf "covered-$TRAVIS_TAG-$TRAVIS_OS_NAME-x86_64.tar.gz" covered
fi
