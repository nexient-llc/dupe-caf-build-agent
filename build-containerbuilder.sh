#!/bin/bash
GIT_SERVER_URL=bitbucket.nextgen.com
GIT_USERNAME=foo # Your Bitbucket username here
GIT_TOKEN=bar # Your Bitbucket access token here

set -e
docker buildx build \
    -t caf-build-agent \
    --build-arg GIT_USERNAME="${GIT_USERNAME}" \
    --build-arg GIT_TOKEN="${GIT_TOKEN}" \
    --build-arg GIT_SERVER_URL="${GIT_SERVER_URL}" \
    --file ./Dockerfile . \
    --no-cache-filter caf \
    --platform linux/amd64 \
    --load


# AWS_PROFILE=pxp-root-admin aws ecr get-login-password | docker login --username AWS --password-stdin 443645626390.dkr.ecr.us-east-2.amazonaws.com
docker tag caf-build-agent 443645626390.dkr.ecr.us-east-2.amazonaws.com/caf-build-agent:dind
docker push 443645626390.dkr.ecr.us-east-2.amazonaws.com/caf-build-agent:dind
