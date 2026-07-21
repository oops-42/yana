#!/usr/bin/env pwsh

$Env:DOCKER_CONTEXT='win25'

docker build -t yana:test -f Dockerfile.win25 .
docker run -ti --rm yana:test @args
