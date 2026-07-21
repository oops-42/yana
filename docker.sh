#!/bin/bash

docker build -t yana:test -f Dockerfile.alpine .
docker run -ti --rm yana:test "$@"
