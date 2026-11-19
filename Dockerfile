FROM docker.io/library/ubuntu:26.04 as BUILDER
ARG OPENSSL_VERSION=4.1.0

USER root


#RUN apt-get update
# 安装编译依赖
COPY --chmod=0755 scripts/apt_install_retry.sh /usr/local/bin/apt-install-retry
RUN /usr/local/bin/apt-install-retry -y \
    build-essential \
    bison \
    ca-certificates \
    cmake \
    ffmpeg \
    gcc \
    git \
    gnupg2 \
    golang \
    imagemagick \
    libc-ares-dev \
    libcmark-dev \
    libgd-dev \
    libimlib2-dev \
    libldap-dev \
    libmagickwand-dev \
    libpcre2-dev \
    libperl-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    make \
    mercurial \
    7zip \
    perl \
    pkg-config \
    libre2-dev \
    tree \
    unzip \
    uuid \
    wget \
    zlib1g-dev \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
    BG_RED="\e[41m"\n\
    BG_GREEN="\e[42m"\n\
    BG_BLUE="\e[44m"\n\
    BG_END="\e[0m"\n\
    URL="$1"\n\
    filename=$(basename -- "$1")\n\
    extension="${filename##*.}"\n\
    filename="${filename%.*}"\n\
    echo -e "${BG_GREEN}## git 下载: $filename ${BG_END}"\n\
    if [ ! -d "$filename" ];then\n\
    hg clone "$URL"\n\
    fi'\
    >/sbin/hg_clone.sh

RUN echo '#!/bin/bash\n\
    BG_RED="\e[41m"\n\
    BG_GREEN="\e[42m"\n\
    BG_BLUE="\e[44m"\n\
    BG_END="\e[0m"\n\
    URL="$1"\n\
    filename=$(basename -- "$1")\n\
    extension="${filename##*.}"\n\
	    filename="${filename%.*}"\n\
	    echo -e "${BG_GREEN}## git 下载: $filename ${BG_END}"\n\
	    if [ -d "$filename" ] && [ ! -d "$filename/.git" ]; then\n\
	    rm -rf "$filename"\n\
	    fi\n\
	    if [ ! -d "$filename" ];then\n\
	    git clone "$URL"\n\
	    fi\n\
    pushd "$filename"\n\
    git pull\n\
    git submodule update --init\n\
    popd\n\
    '\
    >/sbin/git_clone.sh


RUN echo '#!/bin/bash\n\
    BG_RED="\e[41m"\n\
    BG_GREEN="\e[42m"\n\
    BG_BLUE="\e[44m"\n\
    BG_END="\e[0m"\n\
    URL="$1"\n\
    TAR_NAME="$2"\n\
    if [ ! -f "${TAR_NAME}" ]; then\n\
    echo -e "${BG_GREEN}## wget下载: ${URL} -> ${TAR_NAME}${BG_END}"\n\
    rm -rf "${TAR_NAME}.tmp"\n\
    wget --quiet "${URL}" -O "${TAR_NAME}.tmp"\n\
    if [ $? -eq 0 ];then\n\
    mv "${TAR_NAME}.tmp" "${TAR_NAME}"\n\
    else\n\
    echo -e "${BG_RED}下载出错! $? ->${TAR_NAME} , ${URL}${BG_END}"\n\
    exit -1\n\
    fi\n\
    else\n\
    echo ${TAR_NAME}" skip..."\n\
    fi\n\
    '\
    >/sbin/wget_download.sh



RUN echo '#!/bin/bash\n\
    BG_RED="\e[41m"\n\
    BG_GREEN="\e[42m"\n\
    BG_BLUE="\e[44m"\n\
    BG_END="\e[0m"\n\
    URL="$1"\n\
    TAR_NAME="$2"\n\
    DIR_NAME="$3"\n\
    if [ ! -d "$DIR_NAME" ];then\n\
    /sbin/wget_download.sh "$URL" "$TAR_NAME"\n\
    echo -e "${BG_GREEN}解压文件: ${TAR_NAME} -> ${DIR_NAME}${BG_END}"\n\
    rm -rf "${DIR_NAME}.tmp"\n\
    mkdir -p "${DIR_NAME}.tmp"\n\
    tar -zxf "${TAR_NAME}" -C "${DIR_NAME}.tmp" --strip-components 1\n\
    if [ $? -eq 0 ];then\n\
    mv "${DIR_NAME}.tmp" "${DIR_NAME}"\n\
    else\n\
    echo -e "${BG_RED}解压出错! $? $(pwd) tar -zxf \"${TAR_NAME}\" -C \"${DIR_NAME}.tmp\" --strip-components 1 ${BG_END}"\n\
    exit -1\n\
    fi\n\
    else\n\
    echo "文件夹${DIR_NAME}就绪,跳过"\n\
    fi\n\
    '\
    >/sbin/gzip_download.sh



RUN echo '#!/bin/bash\n\n\
    BG_RED="\e[41m"\n\
    BG_GREEN="\e[42m"\n\
    BG_BLUE="\e[44m"\n\
    BG_END="\e[0m"\n\
    URL="$1"\n\
    TAR_NAME="$2"\n\
    DIR_NAME="$3"\n\
    if [ ! -d "$DIR_NAME" ];then\n\
    /sbin/wget_download.sh "$URL" "$TAR_NAME"\n\
    echo -e "${BG_GREEN}解压文件: ${TAR_NAME} -> ${DIR_NAME}${BG_END}"\n\
    unzip "${TAR_NAME}" -d "${DIR_NAME}.tmp"\n\
    if [ $? -eq 0 ];then\n\
    mv  "${DIR_NAME}.tmp" "${DIR_NAME}"\n\
    fi\n\
    else\n\
    echo "文件夹${DIR_NAME}就绪,跳过"\n\
    fi\n\
    '\
    >/sbin/zip_download.sh

RUN chmod +x /sbin/*_*
RUN ls -lah /sbin/*_*

RUN mkdir -p /builder

WORKDIR /builder

# COPY modules /builder/modules
COPY nginx /builder/nginx
COPY submodules /builder/submodules

RUN tree /builder/

RUN cd "/builder/submodules/libmaxminddb" &&\
    ./configure && \
    make && \
    make install && \
    echo /usr/local/lib  >> /etc/ld.so.conf.d/local.conf

RUN pwd ; ls -lah ;cd /builder/submodules/sregex && \
    make && \
    make install

RUN cd /builder/submodules \
    && wget https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -zxf openssl-${OPENSSL_VERSION}.tar.gz \
    && mv openssl-${OPENSSL_VERSION} openssl


RUN cd /builder/submodules/quickjs \
    && sed -i 's|ftp://ftp.unicode.org|https://www.unicode.org|g' unicode_download.sh \
    && ./unicode_download.sh \
    && CFLAGS='-fPIC' make libquickjs.a

RUN tree /builder/

RUN ldconfig && \
    cd "/builder/nginx" && \
    export SREGEX_INC=/nginx/include && \
    export SREGEX_LIB=/nginx/lib && ls -lah ../submodules/quickjs && \
    ./configure \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-client-body-temp-path=/tmp/nginx/client_temp \
    --http-fastcgi-temp-path=/tmp/nginx/fastcgi_temp \
    --http-proxy-temp-path=/tmp/nginx/proxy_temp \
    --http-scgi-temp-path=/tmp/nginx/scgi_temp \
    --http-uwsgi-temp-path=/tmp/nginx/uwsgi_temp \
    --http-log-path=/var/log/nginx/access.log \
    --lock-path=/run/nginx/nginx.lock \
    --pid-path=/run/nginx/nginx.pid \
    --sbin-path=/sbin/nginx \
    --modules-path=/etc/nginx/modules \
    --group=www \
    --user=www \
    --with-http_v3_module \
    --with-file-aio	\
    --with-http_addition_module	\
    --with-http_auth_request_module	\
    --with-http_dav_module	\
    --with-http_flv_module	\
    --with-http_gunzip_module	\
    --with-http_gzip_static_module	\
    --with-http_image_filter_module	\
    --with-http_mp4_module	\
    --with-http_random_index_module	\
    --with-http_realip_module	\
    --with-http_secure_link_module	\
    --with-http_slice_module	\
    --with-http_ssl_module	\
    --with-http_stub_status_module	\
    --with-http_sub_module	\
    --with-http_v2_module	\
    --with-stream	\
    --with-stream_realip_module	\
    --with-stream_ssl_module	\
    --with-stream_ssl_preread_module	\
    --with-threads \
    --with-http_xslt_module \
    --with-zlib=../submodules/zlib \
    --with-pcre=../submodules/pcre2 \
    --with-pcre-jit \
    --with-openssl=/builder/submodules/openssl \
    --add-module=../submodules/ngx_brotli \
    --add-module=../submodules/ngx_devel_kit \
    --add-module=../submodules/set-misc-nginx-module \
    --with-compat \
    --add-module=../submodules/ngx_http_geoip2_module \
    --add-module=../submodules/nginx-module-vts \
    --add-module=../submodules/nginx-module-sts \
    --add-module=../submodules/nginx-module-stream-sts \
    --add-module=../submodules/headers-more-nginx-module \
    --add-module=../submodules/array-var-nginx-module \
    --add-module=../submodules/replace-filter-nginx-module \
    --add-module=../submodules/echo-nginx-module \
    --add-module=../submodules/ngx_markdown_filter_module \
    --add-module=../submodules/nginx-http-auth-digest \
    --add-module=../submodules/ngx_upstream_jdomain  \
    --add-module=../submodules/nginx-vod-module \
    --add-module=../submodules/nginx-rtmp-module \
    --add-module=../submodules/nginx-auth-ldap \
    --add-module=../submodules/njs/nginx  \
    --add-module=../submodules/nginx-dav-ext-module  \
    --add-module=../submodules/ngx-fancyindex  \
    --with-cc-opt="-I/builder/submodules/quickjs" \
    --with-ld-opt="-L/builder/submodules/quickjs" \
    && echo "configure ok" && make -j 2 && make install

RUN cd /builder/submodules/nginx-otel && \
    cmake -S . -B build -DNGX_OTEL_NGINX_BUILD_DIR=/builder/nginx/objs && \
    cmake --build build --parallel 2 && \
    mkdir -p /etc/nginx/modules && \
    cp build/ngx_otel_module.so /etc/nginx/modules/

RUN ldd /sbin/nginx > /etc/nginx/ldd.nginx.txt
RUN ldd /etc/nginx/modules/ngx_otel_module.so > /etc/nginx/ldd.ngx_otel_module.txt
RUN tar -zcf /etc/nginx.tar.gz /etc/nginx
RUN (ldd /sbin/nginx; ldd /etc/nginx/modules/ngx_otel_module.so) | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'




FROM docker.io/library/ubuntu:26.04 as nginx
USER root
COPY --from=BUILDER /etc/nginx /etc/nginx
COPY --from=BUILDER /etc/nginx.tar.gz /etc/nginx/nginx_build.tar.gz
COPY --from=BUILDER /sbin/nginx /sbin/nginx
COPY --from=BUILDER /builder/deps /builder/deps

# 修复权限
COPY --chmod=0755 scripts/apt_install_retry.sh /usr/local/bin/apt-install-retry
RUN /usr/local/bin/apt-install-retry -y --no-install-recommends --no-install-suggests \
    libcap2-bin rsync curl net-tools supervisor logrotate cron ca-certificates openssl \
    && setcap CAP_NET_BIND_SERVICE=+ep /sbin/nginx \
    && apt-get purge -y --auto-remove \
    -o APT::AutoRemove::RecommendsImportant=false \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

RUN /usr/bin/rsync -a /builder/deps/* / && rm -rf /builder/deps/

RUN echo /nginx/lib  >> /etc/ld.so.conf.d/local.conf
RUN echo /usr/local/lib  >> /etc/ld.so.conf.d/local.conf

RUN ldconfig && export SREGEX_INC=/nginx/include && \
    export SREGEX_LIB=/nginx/lib

RUN useradd -ms /bin/sh www

RUN mkdir -p /var/log/nginx && chown -R www:www /var/log/nginx
RUN mkdir -p /tmp/nginx/client_temp && \
    mkdir -p /tmp/nginx/fastcgi_temp  &&  \
    mkdir -p /tmp/nginx/proxy_temp \
    mkdir -p /tmp/nginx/scgi_temp && chown -R www:www /tmp/nginx
RUN mkdir -p /run/nginx && chown -R www:www /run/nginx
RUN mkdir -p /etc/nginx/modules /etc/nginx/modules-enabled && chown -R www:www /etc/nginx
RUN mkdir -p /usr/local/nginx/cache && chown -R www:www /usr/local/nginx/cache

RUN mkdir -p /etc/nginx/custom_global && mkdir -p /etc/nginx/custom_http && mkdir -p /etc/nginx/custom_stream && mkdir -p /etc/nginx/ssl

RUN printf 'load_module /etc/nginx/modules/ngx_otel_module.so;\nevents {}\nhttp {}\n' > /tmp/nginx_otel_test.conf && \
    /sbin/nginx -t -c /tmp/nginx_otel_test.conf


# USER www
WORKDIR /home/www

COPY config /etc/nginx/
COPY GeoIP /var/lib/GeoIP
RUN openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -sha256 -days 3650 \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    -keyout /etc/nginx/ssl/dummy_ecc.key \
    -out /etc/nginx/ssl/dummy_ecc.crt && \
    chmod 600 /etc/nginx/ssl/dummy_ecc.key && \
    chmod 644 /etc/nginx/ssl/dummy_ecc.crt
COPY nginx_startup.sh /nginx_startup.sh
COPY supervisord /etc/supervisor/conf.d/supervisord.conf
# ADD logrotate /etc/cron.daily/logrotate
# ADD logrotate.conf /etc/logrotate.conf
RUN chmod +x /nginx_startup.sh
# logrotate 配置
RUN mkdir -p /etc/crontabs && echo "${CRON_SCHEDULE}	/usr/sbin/logrotate -v /etc/logrotate.conf" >> /etc/crontabs/root \
    &&  echo "include /etc/logrotate.d" > /etc/logrotate.conf \
    &&  mkdir -p /etc/logrotate.d
ADD logrotate.nginx.conf /etc/logrotate.d/nginx

CMD ["/usr/bin/supervisord","-c","/etc/supervisor/conf.d/supervisord.conf"]
