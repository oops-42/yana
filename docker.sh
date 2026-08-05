#!/bin/bash

docker build -t yana:test -f Dockerfile.ubuntu .
docker run -ti --rm yana:test "$@"
