#!/bin/bash
BG_RED="\\e[41m"
BG_GREEN="\\e[42m"
BG_BLUE="\\e[44m"
BG_END="\\e[0m"
URL="$1"
filename=$(basename -- "$1")
extension="${filename##*.}"
filename="${filename%.*}"
echo -e "${BG_GREEN}## git 下载: $filename ${BG_END}"
if [ ! -d "$filename" ];then
    hg clone "$URL"
fi
