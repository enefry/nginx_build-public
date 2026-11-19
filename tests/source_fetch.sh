#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.."; pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

git init -q -b main "$TEST_DIR/upstream/module"
git -C "$TEST_DIR/upstream/module" commit -q --allow-empty -m initial
PIN=$(git -C "$TEST_DIR/upstream/module" rev-parse HEAD)
git -C "$TEST_DIR/upstream/module" commit -q --allow-empty -m next
LATEST=$(git -C "$TEST_DIR/upstream/module" rev-parse HEAD)
mkdir "$TEST_DIR/work"
cd "$TEST_DIR/work"

# Pinning must work on both a fresh clone and a repeated update.
"$ROOT/scripts/git_clone.sh" "$TEST_DIR/upstream/module" "$PIN"
test "$(git -C module rev-parse HEAD)" = "$PIN"
"$ROOT/scripts/git_clone.sh" "$TEST_DIR/upstream/module" "$PIN"
test "$(git -C module rev-parse HEAD)" = "$PIN"

# Existing submodules are detached; updating must still select remote HEAD.
"$ROOT/scripts/git_clone.sh" "$TEST_DIR/upstream/module"
test "$(git -C module rev-parse HEAD)" = "$LATEST"

# A failed clone inside a repository must not reset or clean that repository.
git init -q -b main .
git commit -q --allow-empty -m parent
printf 'keep me\n' > sentinel
PARENT=$(git rev-parse HEAD)
if "$ROOT/scripts/git_clone.sh" "$TEST_DIR/missing"; then
    echo 'ERROR: failed clone returned success' >&2
    exit 1
fi
test "$(git rev-parse HEAD)" = "$PARENT"
test -f sentinel

# A .git file (as used by submodules) must not cause deletion of the checkout.
git -C module worktree add -q --detach "$TEST_DIR/work/file-module" "$PIN"
mkdir -p "$TEST_DIR/other"
git clone -q --bare "$TEST_DIR/upstream/module" "$TEST_DIR/other/file-module"
"$ROOT/scripts/git_clone.sh" "$TEST_DIR/other/file-module" "$PIN"
test -f file-module/.git
test "$(git -C file-module rev-parse HEAD)" = "$PIN"

# Download failures must propagate through the extraction helper.
mkdir "$TEST_DIR/bin"
printf '#!/bin/sh\nexit 23\n' > "$TEST_DIR/bin/wget"
chmod +x "$TEST_DIR/bin/wget"
if PATH="$TEST_DIR/bin:$PATH" "$ROOT/scripts/gzip_download.sh" \
    https://invalid.example/source.tar.gz "$TEST_DIR/source.tar.gz" "$TEST_DIR/source"; then
    echo 'ERROR: failed download returned success' >&2
    exit 1
fi
test ! -e "$TEST_DIR/source"

# The top-level source step must also stop when a helper fails.
mkdir -p "$TEST_DIR/driver/scripts"
cp "$ROOT/update_sources.sh" "$TEST_DIR/driver/"
printf '#!/bin/sh\nexit 23\n' > "$TEST_DIR/driver/scripts/gzip_download.sh"
chmod +x "$TEST_DIR/driver/scripts/gzip_download.sh"
if NGINX_VERSION=1.0 "$TEST_DIR/driver/update_sources.sh"; then
    echo 'ERROR: top-level source step ignored a failed helper' >&2
    exit 1
fi
test ! -e "$TEST_DIR/driver/nginx"
echo 'Source-fetch regression checks passed.'
