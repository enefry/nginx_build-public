#!/bin/bash
set -euo pipefail
BG_RED="\\e[41m"
BG_GREEN="\\e[42m"
BG_BLUE="\\e[44m"
BG_END="\\e[0m"
URL="$1"
TAR_NAME="$2"

if [ ! -f "${TAR_NAME}" ]; then
    echo -e "${BG_GREEN}## wget下载: ${URL} -> ${TAR_NAME}${BG_END}"
    rm -rf "${TAR_NAME}.tmp"
    wget --quiet "${URL}" -O "${TAR_NAME}.tmp"
    if [ $? -eq 0 ];then
        mv "${TAR_NAME}.tmp" "${TAR_NAME}"
    else
        echo -e "${BG_RED}下载出错! $? ->${TAR_NAME} , ${URL}${BG_END}"
        exit -1
    fi
else
    echo ${TAR_NAME}" skip..."
fi
