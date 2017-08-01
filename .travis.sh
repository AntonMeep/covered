#!/bin/bash

dub test --compiler=$DC

echo "Building $TRAVIS_TAG for $TRAVIS_OS_NAME x86_64 using $DC"
dub build -b release --compiler=$DC
tar -zcf "covered-$TRAVIS_TAG-$TRAVIS_OS_NAME-$DC-x86_64.tar.gz" covered

echo
echo

if [ "$DC" != ldc ]; then
	echo "Building $TRAVIS_TAG for $TRAVIS_OS_NAME x86 using $DC"
	dub build -b release --compiler=$DC --arch=x86
	tar -zcf "covered-$TRAVIS_TAG-$TRAVIS_OS_NAME-$DC-x86.tar.gz" covered
fi

