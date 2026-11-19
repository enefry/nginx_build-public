#!/bin/bash
set -euo pipefail
BG_RED="\\e[41m"
BG_GREEN="\\e[42m"
BG_BLUE="\\e[44m"
BG_END="\\e[0m"
URL="$1"
TAR_NAME="$2"
DIR_NAME="$3"
SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
if [ ! -d "$DIR_NAME" ];then
    "${SHELL_FOLDER}/wget_download.sh" "$URL" "$TAR_NAME"
    echo -e "${BG_GREEN}解压文件: ${TAR_NAME} -> ${DIR_NAME}${BG_END}"
    rm -rf "${DIR_NAME}.tmp"
    mkdir -p "${DIR_NAME}.tmp"
    tar -zxf "${TAR_NAME}" -C "${DIR_NAME}.tmp" --strip-components 1
    if [ $? -eq 0 ];then
        mv "${DIR_NAME}.tmp" "${DIR_NAME}"
    else
        echo -e "${BG_RED}解压出错! $? $(pwd) tar -zxf \"${TAR_NAME}\" -C \"${DIR_NAME}.tmp\" --strip-components 1 ${BG_END}"
        exit -1
    fi
else
    echo "文件夹${DIR_NAME}就绪,跳过"
fi
