#!/bin/bash

dub test --compiler=$DC

echo "Building $TRAVIS_TAG for $TRAVIS_OS_NAME x86_64 using $DC"
dub build -b release --compiler=$DC
tar -zcf "covered-$TRAVIS_TAG-$TRAVIS_OS_NAME-$DC-x86_64.tar.gz" covered
