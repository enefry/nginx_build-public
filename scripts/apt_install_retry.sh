#!/bin/sh
set -eu

attempts=${APT_RETRY_ATTEMPTS:-5}
delay=${APT_RETRY_DELAY:-10}
case "$attempts" in
    ''|*[!0-9]*|0) echo "APT_RETRY_ATTEMPTS must be a positive integer" >&2; exit 2 ;;
esac
case "$delay" in
    ''|*[!0-9]*) echo "APT_RETRY_DELAY must be a nonnegative integer" >&2; exit 2 ;;
esac
if [ "$#" -eq 0 ]; then
    echo "Usage: apt_install_retry.sh [install options] package..." >&2
    exit 2
fi

attempt=1
while :; do
    if apt-get -o Acquire::Retries=3 -o Acquire::http::No-Cache=true \
        -o APT::Update::Error-Mode=any update && \
        apt-get -o Acquire::Retries=3 install "$@"; then
        exit 0
    else
        status=$?
    fi

    # Discard a stale/partial index before fetching a consistent mirror snapshot.
    rm -rf /var/lib/apt/lists/*
    if [ "$attempt" -ge "$attempts" ]; then
        echo "APT update/install failed after $attempt attempts (exit $status)" >&2
        exit "$status"
    fi
    wait_seconds=$((delay * attempt))
    echo "APT update/install failed (attempt $attempt/$attempts); retrying in ${wait_seconds}s" >&2
    sleep "$wait_seconds"
    attempt=$((attempt + 1))
done
