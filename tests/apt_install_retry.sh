#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.."; pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir "$TEST_DIR/bin"

cat > "$TEST_DIR/bin/apt-get" <<'SH'
#!/bin/sh
set -eu
case " $* " in
    *" update "*) phase=update ;;
    *" install "*) phase=install ;;
    *) exit 90 ;;
esac
count=0
if [ -f "$APT_TEST_STATE/$phase" ]; then
    count=$(cat "$APT_TEST_STATE/$phase")
fi
count=$((count + 1))
echo "$count" > "$APT_TEST_STATE/$phase"
printf '%s\n' "$*" >> "$APT_TEST_STATE/args"
case "$APT_TEST_CASE:$phase:$count" in
    update-once:update:1|install-once:install:1|always-update:update:*|always-install:install:*)
        echo 'File has unexpected size. Mirror sync in progress?' >&2
        exit 100 ;;
esac
SH
cat > "$TEST_DIR/bin/rm" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$APT_TEST_STATE/cleanup"
SH
cat > "$TEST_DIR/bin/sleep" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$APT_TEST_STATE/sleeps"
SH
chmod +x "$TEST_DIR/bin/"*

check_case() {
    local name=$1 expected_status=$2 updates=$3 installs=$4 cleanups=$5
    local state="$TEST_DIR/$name" status=0
    mkdir "$state"
    PATH="$TEST_DIR/bin:$PATH" APT_TEST_STATE="$state" APT_TEST_CASE="$name" \
        APT_RETRY_ATTEMPTS=3 APT_RETRY_DELAY=0 \
        sh "$ROOT/scripts/apt_install_retry.sh" -y fixture-package > "$state/log" 2>&1 || status=$?
    test "$status" -eq "$expected_status"
    test "$(cat "$state/update")" -eq "$updates"
    if [ "$installs" -eq 0 ]; then
        test ! -e "$state/install"
    else
        test "$(cat "$state/install")" -eq "$installs"
        grep -q 'install -y fixture-package' "$state/args"
    fi
    if [ "$cleanups" -eq 0 ]; then
        test ! -e "$state/cleanup"
        test ! -e "$state/sleeps"
    else
        test "$(wc -l < "$state/cleanup")" -eq "$cleanups"
        grep -q '/var/lib/apt/lists/' "$state/cleanup"
    fi
    grep -q 'Acquire::http::No-Cache=true' "$state/args"
    grep -q 'APT::Update::Error-Mode=any' "$state/args"
}

check_case success 0 1 1 0
check_case update-once 0 2 1 1
check_case install-once 0 2 2 1
check_case always-update 100 3 0 3
check_case always-install 100 3 3 3
echo 'APT retry regression checks passed.'
