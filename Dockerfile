# docker build -t nginx-php-fpm -f Dockerfile .
#
# To run the above docker container for testing, you can run following command from your terminal:
#
# docker run -ti --network host nginx-php-fpm
#
# On the above `--network host`, we are trying to use host machine's network.

FROM debian:buster-slim AS build

WORKDIR /var/www/hello-world
ADD . /var/www/hello-world

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y g++ gcc libc-dev autoconf dpkg-dev file make pkg-config re2c \
 curl wget git xz-utils lsb-release apt-transport-https ca-certificates

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -

RUN apt-get update && apt-get install -y php7.4-fpm php7.4-apcu php7.4-bcmath php7.4-bz2 php7.4-curl php7.4-dba \
 php7.4-xml php7.4-gd php7.4-gmp php7.4-intl php7.4-mbstring php7.4-mongodb php7.4-mysql php7.4-redis \
 php7.4-zip php7.4-msgpack php7.4-xmlrpc nodejs supervisor nginx

# If you need a nginx cache directory.
RUN mkdir -p /var/cache/nginx/hello-world && mkdir -p /var/lib/nginx

# If you need `composer`
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -d memory_limit=512M composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/bin/composer && mkdir -p /run/php-fpm && mkdir -p /var/log/php-fpm

# Copy custom nginx.conf, hworld-vhost.conf, php-fpm.conf and hworld-fpm.conf file.
RUN cp /var/www/hello-world/nginx.conf /etc/nginx/nginx.conf && \
    cp /var/www/hello-world/hworld-vhost.conf /etc/nginx/conf.d/hworld-vhost.conf && \
    cp /var/www/hello-world/php-fpm.conf /etc/php/7.4/fpm/php-fpm.conf && \
    cp /var/www/hello-world/hworld-fpm.conf /etc/php/7.4/fpm/pool.d/hworld-fpm.conf

# Delete default php-fpm config file.
RUN rm -f /etc/php/7.4/fpm/pool.d/www.conf

RUN set -eux; \
 cd /etc/supervisor; \
 { \
  echo '[supervisord]'; \
  echo 'user=root'; \
  echo 'nodaemon=true'; \
  echo 'logfile=/dev/null'; \
  echo 'logfile_maxbytes=0'; \
  echo 'pidfile=/var/run/supervisord.pid'; \
  echo; \
  echo '[include]'; \
  echo 'files = /etc/supervisor/conf.d/*.conf'; \
 } | tee supervisord.conf; \
 { \
  echo '[program:php-fpm]'; \
  echo 'command=php-fpm -F'; \
  echo 'stdout_logfile=/dev/stdout'; \
  echo 'stdout_logfile_maxbytes=0'; \
  echo 'stderr_logfile=/dev/stderr'; \
  echo 'stderr_logfile_maxbytes=0'; \
  echo 'autostart=true'; \
  echo 'autorestart=true'; \
  echo 'startretries=0'; \
  echo 'priority=1'; \
 } | tee conf.d/php-fpm.conf; \
 { \
  echo '[program:nginx]'; \
  echo 'command=nginx -g "daemon off;"'; \
  echo 'stdout_logfile=/dev/stdout'; \
  echo 'stdout_logfile_maxbytes=0'; \
  echo 'stderr_logfile=/dev/stderr'; \
  echo 'stderr_logfile_maxbytes=0'; \
  echo 'autostart=true'; \
  echo 'autorestart=true'; \
  echo 'startretries=0'; \
  echo 'priority=2'; \
 } | tee conf.d/nginx.conf

FROM gcr.io/distroless/base:debug

COPY --from=build /var/www/hello-world /var/www/hello-world

WORKDIR /var/www/hello-world

COPY --from=build /run/php-fpm /run/php-fpm
COPY --from=build /var/log /var/log
COPY --from=build /var/run /var/run
COPY --from=build /var/cache/nginx /var/cache/nginx
COPY --from=build /var/lib/nginx /var/lib/nginx
COPY --from=build /var/lib/php /var/lib/php
COPY --from=build /etc/php /etc/php
COPY --from=build /usr/bin/php7.4 /usr/bin/php
COPY --from=build /usr/sbin/php-fpm7.4 /usr/bin/php-fpm
COPY --from=build /usr/bin/python2 /usr/bin/python2
COPY --from=build /usr/bin/python /usr/bin/python

# For nginx
COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/bin/nginx
COPY --from=build /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/

# For php
COPY --from=build /usr/lib/x86_64-linux-gnu/libargon2.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libresolv.so.2 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libxml2.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libsodium.so.23 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/
COPY --from=build /lib64/ld-linux-x86-64.so.2 /lib64/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicui18n.so.63 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicuuc.so.63 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicudata.so.63 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/liblzma.so.5 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libsnappy.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libbz2.so.1.0 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libcurl.so.4 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libdb-5.3.so /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libffi.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libgd.so.3 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libgmp.so.10 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicuio.so.65 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libonig.so.5 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libsasl2.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libxslt.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libnghttp2.so.14 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/liblmdb.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libpng16.so.16 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicui18n.so.65 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libexslt.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libidn2.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/libqdbm.so.14 /usr/lib/
COPY --from=build /usr/lib/x86_64-linux-gnu/libfontconfig.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicuuc.so.65 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libedit.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libgcrypt.so.20 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/librtmp.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libicudata.so.65 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libbsd.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libgpg-error.so.0 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libssh2.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libjpeg.so.62 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libpsl.so.5 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libXpm.so.4 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libtiff.so.5 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libgssapi_krb5.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libwebp.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libkrb5.so.3 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libuuid.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libexpat.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libk5crypto.so.3 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libcom_err.so.2 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libX11.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libldap_r-2.4.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/liblber-2.4.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libjbig.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libunistring.so.2 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libxcb.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libgnutls.so.30 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libXau.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libXdmcp.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libhogweed.so.4 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libnettle.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libkrb5support.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libkeyutils.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libp11-kit.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libtasn1.so.6 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libzip.so.4 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libxmlrpc-epi.so.0 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/php /usr/lib/php

# For php-fpm
COPY --from=build /usr/lib/x86_64-linux-gnu/libacl.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libapparmor.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libsystemd.so.0 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libattr.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/liblz4.so.1 /usr/lib/x86_64-linux-gnu/

# For python2
COPY --from=build /lib/x86_64-linux-gnu/libutil.so.1 /lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libzip.so.4 /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/python2.7 /usr/lib/python2.7

# For supervisor
COPY --from=build /etc/supervisor /etc/supervisor
COPY --from=build /usr/bin/supervisord /usr/bin/supervisord
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

# This is important for nginx as it is using libnss to query user information from `/etc/passwd` otherwise
# you will receive error like `nginx: [emerg] getpwnam("nonroot") failed`.
COPY --from=build /lib/x86_64-linux-gnu/libnss_compat.so.2 /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libnss_files.so.2 /lib/x86_64-linux-gnu/

EXPOSE 9000 80
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]