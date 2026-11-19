#!/bin/bash
set -euo pipefail

# 设置基础目录
BASE_DIR=$(cd "$(dirname "$0")"/..; pwd)
cd "$BASE_DIR"

# 1. 从 nginx.org 下载页解析 mainline 与 stable 版本
#    页面 HTML 是单行的, 不能用 awk 按行段落切分.
#    页面里 <a href="/download/nginx-X.Y.Z.tar.gz"> 的出现顺序固定为:
#      第 1 个 = mainline, 第 2 个 = stable, 之后是 legacy
DOWNLOAD_HTML=$(curl --fail --silent --show-error --retry 3 https://nginx.org/en/download.html)

NGINX_TARBALLS=$(echo "$DOWNLOAD_HTML" \
    | grep -oE '/download/nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' \
    | awk '!seen[$0]++' \
    | sed -E 's|.*/nginx-([0-9.]+)\.tar\.gz|\1|')

NEW_NGINX_MAINLINE=$(echo "$NGINX_TARBALLS" | sed -n '1p')
NEW_NGINX_STABLE=$(echo "$NGINX_TARBALLS" | sed -n '2p')

# 2. 检测最新 OpenSSL 版本
API_HEADERS=(-H "Accept: application/vnd.github+json")
if [ -n "${GITHUB_TOKEN:-}" ]; then
    API_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
OPENSSL_JSON=$(curl --fail --silent --show-error --retry 3 "${API_HEADERS[@]}" https://api.github.com/repos/openssl/openssl/releases/latest)
if ! NEW_OPENSSL_TAG=$(jq -er '.tag_name | select(type == "string" and test("^openssl-[0-9]+[.][0-9]+[.][0-9]+$"))' <<< "$OPENSSL_JSON"); then
    echo "::error::Could not read a valid OpenSSL release tag" >&2
    exit 1
fi
NEW_OPENSSL_VER="${NEW_OPENSSL_TAG#openssl-}"

if [[ ! "$NEW_NGINX_MAINLINE" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ || ! "$NEW_NGINX_STABLE" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
    echo "::error::Could not read both nginx release versions" >&2
    exit 1
fi

# 读取当前版本
if [ -f versions.env ]; then
    OLD_NGINX_MAINLINE=$(grep -oP '^NGINX_MAINLINE_VERSION=\K.*' versions.env)
    OLD_NGINX_STABLE=$(grep -oP '^NGINX_STABLE_VERSION=\K.*' versions.env)
    OLD_OPENSSL=$(grep -oP '^OPENSSL_VERSION=\K.*' versions.env)
else
    OLD_NGINX_MAINLINE=""
    OLD_NGINX_STABLE=""
    OLD_OPENSSL=""
fi

echo "检测结果:"
echo "Nginx mainline: $OLD_NGINX_MAINLINE -> $NEW_NGINX_MAINLINE"
echo "Nginx stable:   $OLD_NGINX_STABLE -> $NEW_NGINX_STABLE"
echo "OpenSSL:        $OLD_OPENSSL -> $NEW_OPENSSL_VER"

UPDATED=false
CHANGES=()

upsert_var() {
    local key="$1" value="$2"
    if grep -q "^${key}=" versions.env; then
        sed -i "s/^${key}=.*/${key}=${value}/" versions.env
    else
        echo "${key}=${value}" >> versions.env
    fi
}

if [ -n "$NEW_NGINX_MAINLINE" ] && [ "$NEW_NGINX_MAINLINE" != "$OLD_NGINX_MAINLINE" ]; then
    echo "更新 Nginx mainline 到 $NEW_NGINX_MAINLINE..."
    upsert_var "NGINX_MAINLINE_VERSION" "$NEW_NGINX_MAINLINE"
    CHANGES+=("nginx mainline -> $NEW_NGINX_MAINLINE")
    UPDATED=true
fi

if [ -n "$NEW_NGINX_STABLE" ] && [ "$NEW_NGINX_STABLE" != "$OLD_NGINX_STABLE" ]; then
    echo "更新 Nginx stable 到 $NEW_NGINX_STABLE..."
    upsert_var "NGINX_STABLE_VERSION" "$NEW_NGINX_STABLE"
    CHANGES+=("nginx stable -> $NEW_NGINX_STABLE")
    UPDATED=true
fi

if [ -n "$NEW_OPENSSL_VER" ] && [ "$NEW_OPENSSL_VER" != "$OLD_OPENSSL" ]; then
    echo "更新 OpenSSL 到 $NEW_OPENSSL_VER..."
    upsert_var "OPENSSL_VERSION" "$NEW_OPENSSL_VER"
    CHANGES+=("openssl -> $NEW_OPENSSL_VER")
    UPDATED=true
fi

if [ "$UPDATED" = true ]; then
    echo "检测到版本更新，准备提交变更。"
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git add versions.env
    git commit -m "chore: auto update $(IFS=', '; echo "${CHANGES[*]}")"
    git push
else
    echo "当前已是最新版本，无需更新。"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "updated=${UPDATED}" >> "$GITHUB_OUTPUT"
fi
