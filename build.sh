#!/bin/bash

# https://nginx.org
SCRIPTS_PATH="$(cd "$(dirname "$0")";pwd)"
echo "$SCRIPTS_PATH"
VERSION="$(cat $SCRIPTS_PATH/.github/workflows/build.yml| grep "renwei/nginx:"| grep -v "latest" | awk -F: '{print $2}')"
echo "VERSION=$VERSION"
export VERSION="$VERSION"
cat "version_records/latest.txt"
#echo docker buildx build --platform linux/amd64,linux/arm64 -t "renwei/nginx:${VERSION}" . --push
docker -D --log-level "info" buildx build --build-arg ARGV_NGINX_VERSION=$VERSION --platform linux/amd64,linux/arm64 -t "quay.io/renwei_chen/nginx:${VERSION}" . --push # 2>&1
docker -D --log-level "info" buildx build --build-arg ARGV_NGINX_VERSION=$VERSION --platform linux/amd64,linux/arm64 -t "renwei/nginx:${VERSION}" . --push # 2>&1
