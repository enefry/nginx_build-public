#!/bin/bash
set -euo pipefail
BG_RED="\\e[41m"
BG_GREEN="\\e[42m"
BG_BLUE="\\e[44m"
BG_END="\\e[0m"
URL="${1:?repository URL is required}"
REF="${2:-}"
filename=$(basename -- "$URL")
filename="${filename%.git}"
echo -e "${BG_GREEN}## git 下载: $filename ${BG_END}"
if [ -d "$filename" ] && [ ! -e "$filename/.git" ]; then
    rm -rf "$filename"
fi
if [ ! -d "$filename" ];then
    git clone "$URL" "$filename"
fi
pushd "$filename"
    git remote set-url origin "$URL"
    git clean -f
    git reset --hard
    if [ -n "$REF" ]; then
        git fetch origin "$REF"
        git checkout --detach "$REF"
    else
        git fetch origin
        git remote set-head origin --auto
        git checkout --detach origin/HEAD
    fi
    git submodule update --init --recursive
popd
