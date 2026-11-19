#!/bin/bash

set -euo pipefail
SCRIPTS_PATH="$(cd "$(dirname "$0")";pwd)"
echo "$SCRIPTS_PATH"
if [ -f "$SCRIPTS_PATH/versions.env" ]; then
    # 仅在外部未指定 NGINX_VERSION 时才读取 versions.env 中的默认值
    # (build.yml 的 matrix 会按 track 预先导出 NGINX_VERSION)
    if [ -z "${NGINX_VERSION:-}" ]; then
        source "$SCRIPTS_PATH/versions.env"
        # 默认使用 mainline
        NGINX_VERSION="${NGINX_MAINLINE_VERSION:-$NGINX_VERSION}"
    fi
fi
echo "NGINX_VERSION=$NGINX_VERSION"

SHELL_FOLDER="$SCRIPTS_PATH"
cd "$SHELL_FOLDER"
MODULE_PATH="${SHELL_FOLDER}/submodules"
SCRIPTS_PATH="${SHELL_FOLDER}/scripts"
DOWNLOAD_PATH="${SHELL_FOLDER}/downloads"

mkdir -p "$MODULE_PATH" "$DOWNLOAD_PATH" "$SHELL_FOLDER/version_records"
TODAY=$(date +%Y-%m-%d)

VERSION_RECORD="${SHELL_FOLDER}/version_records/$TODAY.txt"
(
    echo ""
    echo "---------$(date)--------"
    echo "nginx: ${NGINX_VERSION}"
)> "$VERSION_RECORD"

function download_latest_github_gzip()
{
    GITHUB_ORGANIZATION="$1"
    GITHUB_PROJECT="$2"
    UNZIP_PATH="$3"
    JSON_FILE_NAME="$DOWNLOAD_PATH/${GITHUB_ORGANIZATION}_${GITHUB_PROJECT}_${TODAY}.json"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsS -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_ORGANIZATION/${GITHUB_PROJECT}/releases/latest" -o "$JSON_FILE_NAME"
    else
        curl -fsS "https://api.github.com/repos/$GITHUB_ORGANIZATION/${GITHUB_PROJECT}/releases/latest" -o "$JSON_FILE_NAME"
    fi
    TAG_NAME=$(cat "$JSON_FILE_NAME" | jq -r '.tag_name') #$()

    URL=$(cat "$JSON_FILE_NAME" | jq -r '.assets[] | select(.content_type == "application/gzip") | .browser_download_url')
    if [ -z "$URL" ];then
        URL=$(cat "$JSON_FILE_NAME" | jq -r '.assets[] | select(.content_type == "application/x-gtar") | .browser_download_url')
    fi
    if [ -z "$URL" ];then
        URL=$(cat "$JSON_FILE_NAME" | jq -r '.assets[] | select(.content_type == "application/x-gzip") | .browser_download_url')
    fi
    "$SCRIPTS_PATH/gzip_download.sh" "$URL" "$DOWNLOAD_PATH/${GITHUB_ORGANIZATION}_${GITHUB_PROJECT}_${TAG_NAME}.gzip" "${UNZIP_PATH}"
    echo "${GITHUB_ORGANIZATION}/${GITHUB_PROJECT} : $TAG_NAME" >> "$VERSION_RECORD"
}

function update_git_resp()
{
    local GIT_REMOTE="$1"
    local GIT_REF="${2:-}"
    local filename TAG_NAME
    filename=$(basename -- "$GIT_REMOTE")
    filename="${filename%.git}"

    "${SCRIPTS_PATH}/git_clone.sh" "$GIT_REMOTE" "$GIT_REF"
    TAG_NAME="$(git -C "$filename" rev-parse HEAD)"
    echo "${filename}: $TAG_NAME" >> "$VERSION_RECORD"
}

function update_hg_resp()
{

    filename=$(basename -- "$1")
    extension="${filename##*.}"
    filename="${filename%.*}"
    "${SCRIPTS_PATH}/hg_clone.sh" "$1"
    pushd "$filename" ; TAG_NAME="$(hg id -i)"; popd
    echo "${filename}: $TAG_NAME" >> "$VERSION_RECORD"
}


# 下载 nginx
NGINX_DIRNAME="nginx-${NGINX_VERSION}"
NGINX_TARFILENAME=${NGINX_DIRNAME}".tar.gz"
"$SCRIPTS_PATH/gzip_download.sh" "https://nginx.org/download/${NGINX_TARFILENAME}" "${NGINX_TARFILENAME}" "${NGINX_DIRNAME}"

if [ -d 'nginx' ];then
unlink 'nginx'
fi
ln -s "nginx-${NGINX_VERSION}" nginx

# 下载 github 上的 release
rm -rf "submodules/pcre2"
download_latest_github_gzip "PCRE2Project" "pcre2" "submodules/pcre2"
rm -rf "submodules/libmaxminddb"
download_latest_github_gzip "maxmind" "libmaxminddb" "submodules/libmaxminddb"

# 更新 submodule
pushd submodules
update_git_resp "https://github.com/madler/zlib.git"
update_git_resp "https://github.com/google/ngx_brotli.git"
update_git_resp "https://github.com/openresty/set-misc-nginx-module.git"
update_git_resp "https://github.com/leev/ngx_http_geoip2_module.git"
update_git_resp "https://github.com/vozlt/nginx-module-vts.git"
update_git_resp "https://github.com/vozlt/nginx-module-sts.git"
update_git_resp "https://github.com/vozlt/nginx-module-stream-sts.git"
update_git_resp "https://github.com/nginxinc/nginx-otel.git"
update_git_resp "https://github.com/vision5/ngx_devel_kit.git"
update_git_resp "https://github.com/openresty/array-var-nginx-module.git"
update_git_resp "https://github.com/openresty/replace-filter-nginx-module.git"
update_git_resp "https://github.com/openresty/sregex.git"
update_git_resp "https://github.com/openresty/headers-more-nginx-module.git"
update_git_resp "https://github.com/openresty/echo-nginx-module.git"
update_git_resp "https://github.com/atomx/nginx-http-auth-digest.git"
update_git_resp "https://github.com/ukarim/ngx_markdown_filter_module.git"
update_git_resp "https://github.com/nicholaschiasson/ngx_upstream_jdomain.git"
# The original Kaltura repository is unavailable. Use the identical, pinned
# upstream commit from its public mirror (also recorded by the submodule).
update_git_resp "https://github.com/dio-az/nginx-vod-module.git" \
    "26f06877b0f2a2336e59cda93a3de18d7b23a3e2"
update_git_resp "https://github.com/kvspb/nginx-auth-ldap.git"
update_git_resp "https://github.com/arut/nginx-dav-ext-module.git"
update_git_resp "https://github.com/aperezdc/ngx-fancyindex.git"
update_git_resp "https://github.com/bellard/quickjs"
update_git_resp  "https://github.com/nginx/njs"
update_git_resp "https://github.com/arut/nginx-rtmp-module.git"
popd
echo "------------------------" >> "$VERSION_RECORD"
cat "$VERSION_RECORD" > "${SHELL_FOLDER}/version_records/latest.txt"
