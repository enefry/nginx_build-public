#!/usr/bin/env bash
set -euo pipefail

image=${1:?Usage: tests/image_smoke.sh IMAGE}
docker run --rm -i --entrypoint /bin/sh "$image" -s <<'CONTAINER'
set -eu
nginx -V
nginx -t
for binary in /sbin/nginx /etc/nginx/modules/ngx_otel_module.so; do
    if ldd "$binary" | grep -q 'not found'; then
        echo "Missing shared library: $binary" >&2
        exit 1
    fi
done
cat > /tmp/smoke.conf <<'CONFIG'
load_module /etc/nginx/modules/ngx_otel_module.so;
pid /tmp/smoke.pid;
error_log stderr;
events {}
http {
    access_log off;
    server {
        listen 8080;
        listen 8443 ssl;
        ssl_certificate /etc/nginx/ssl/dummy_ecc.crt;
        ssl_certificate_key /etc/nginx/ssl/dummy_ecc.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        location / { return 200 "ubuntu-upgrade-ok\n"; }
    }
}
CONFIG
nginx -t -c /tmp/smoke.conf
nginx -c /tmp/smoke.conf
trap 'nginx -s quit -c /tmp/smoke.conf' EXIT
curl --noproxy '*' --fail --silent --show-error --retry 5 --retry-connrefused \
    http://localhost:8080/ | grep -Fx 'ubuntu-upgrade-ok'
for version in 1.2 1.3; do
    curl --noproxy '*' --fail --silent --show-error --cacert /etc/nginx/ssl/dummy_ecc.crt \
        --tlsv"$version" --tls-max "$version" https://localhost:8443/ \
        | grep -Fx 'ubuntu-upgrade-ok'
done
CONTAINER
