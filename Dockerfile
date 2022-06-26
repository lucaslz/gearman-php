ARG PHP_VERSION="8.1"

FROM php:${PHP_VERSION}-cli-alpine

LABEL MAITAINER="Lucas Lima <lucas.developmaster@gmail.com>"

WORKDIR /var/www

ENV TZ=UTC

ENV GEARMAND_VERSION 1.1.19.1

ENV GEARMAND_SHA1 2fc7e7f404268273de847eb41c2b0c3f0e3fec9e

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ARG WWWGROUP

ARG NODE_VERSION=16

RUN addgroup -S gearman && adduser -G gearman -S -D -H -s /bin/false -g "Gearman Server" gearman

# COPY patches/libhashkit-common.h.patch /libhashkit-common.h.patch
COPY patches/libtest-cmdline.cc.patch /libtest-cmdline.cc.patch

RUN apk add -U --no-cache \
    gnupg \
    curl \
    wget \
    vim \
    zip \
    unzip \
    icu-dev \
    gettext \
    gettext-dev \
    libzip-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    freetype-dev \
    libbz2 \
    enchant2-dev \
    gmp-dev \
    imap-dev \
    krb5-dev \
    openssl-dev \
    icu-dev \
    openldap-dev \
    freetds-dev \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    tidyhtml-dev \
    net-snmp-dev \
    aspell-dev \
    nodejs=16.15.0-r1 \
    npm \
    yarn \
    git

RUN wget -O gearmand.tar.gz "https://github.com/gearman/gearmand/releases/download/$GEARMAND_VERSION/gearmand-$GEARMAND_VERSION.tar.gz" \
	&& echo "$GEARMAND_SHA1  gearmand.tar.gz" | sha1sum -c - \
	&& mkdir -p /usr/src/gearmand \
	&& tar -xzf gearmand.tar.gz -C /usr/src/gearmand --strip-components=1 \
	&& rm gearmand.tar.gz \
	&& cd /usr/src/gearmand \
	&& patch -p1 < /libtest-cmdline.cc.patch \
	&& ./configure \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--with-mysql=yes \
		--with-postgresql=no \
		--disable-libpq \
		--disable-libtokyocabinet \
		--disable-libdrizzle \
		--enable-ssl \
		--enable-hiredis \
		--enable-jobserver=no \
	&& make \
	&& make install \
	&& cd / && rm -rf /usr/src/gearmand \
	&& rm /*.patch \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .gearmand-rundeps $runDeps \
	&& apk del .build-deps \
	&& /usr/local/sbin/gearmand --version

RUN apk --no-cache add -U --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ gosu

RUN docker-php-ext-configure gettext \
    && docker-php-ext-install -j$(nproc) gettext

RUN docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) imap

RUN docker-php-ext-configure ldap --with-ldap=/usr \
    && docker-php-ext-install -j$(nproc) ldap

RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install -j$(nproc) pdo_pgsql pgsql

RUN docker-php-ext-install -j$(nproc) \
    mysqli \
    opcache \
    pcntl \
    pdo \
    pdo_mysql \
    shmop \
    sockets \
    sysvmsg \
    sysvsem \
    sysvshm \
    zip \
    bz2 \
    enchant \
    ffi \
    gmp \
    intl \
    pdo_dblib \
    soap \
    xsl \
    tidy \
    snmp \
    pspell

RUN php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

COPY docker-entrypoint.sh /usr/local/bin/

RUN apk add --no-cache bash \
    && touch /etc/gearmand.conf && chown gearman:gearman /etc/gearmand.conf \
    && ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

RUN rm -rf /var/cache/apk/*

ENTRYPOINT ["docker-entrypoint.sh"]

USER gearman

EXPOSE 4730

CMD ["gearmand"]

