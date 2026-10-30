# SuiteCRM 8.10.2 - imagen de produccion con branding Kits & Vet CRM
FROM php:8.1-apache-bookworm

ARG SUITECRM_VERSION=8.10.2
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public \
    SUITECRM_VERSION=${SUITECRM_VERSION}

# --- Extensiones PHP requeridas por SuiteCRM -------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        libicu-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
        libzip-dev libonig-dev libxml2-dev libcurl4-openssl-dev \
        libldap2-dev libc-client-dev libkrb5-dev \
        default-mysql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j"$(nproc)" \
        intl gd zip pdo_mysql mysqli mbstring xml soap bcmath opcache ldap imap \
    && a2enmod rewrite headers remoteip \
    && rm -rf /var/lib/apt/lists/*

# --- php.ini de produccion -------------------------------------------------
RUN { \
        echo 'memory_limit=512M'; \
        echo 'upload_max_filesize=64M'; \
        echo 'post_max_size=64M'; \
        echo 'max_execution_time=300'; \
        echo 'max_input_vars=3000'; \
        echo 'date.timezone=UTC'; \
        echo 'display_errors=Off'; \
        echo 'display_startup_errors=Off'; \
        echo 'log_errors=On'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.revalidate_freq=2'; \
    } > /usr/local/etc/php/conf.d/suitecrm.ini

# --- Apache: DocumentRoot en public/ con .htaccess habilitado --------------
RUN echo 'ServerName localhost' > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
    && printf '%s\n' \
        '<Directory /var/www/html/public>' \
        '    Options -Indexes +FollowSymLinks' \
        '    AllowOverride All' \
        '    Require all granted' \
        '</Directory>' \
        > /etc/apache2/conf-available/suitecrm.conf \
    && a2enconf suitecrm

# --- Codigo de SuiteCRM ----------------------------------------------------
WORKDIR /var/www/html

RUN curl -fsSL -o /tmp/suitecrm.zip \
        "https://github.com/SuiteCRM/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip" \
    && unzip -q /tmp/suitecrm.zip -d /var/www/html \
    && rm -f /tmp/suitecrm.zip \
    && chown -R www-data:www-data /var/www/html

# --- Branding Kits & Vet CRM -----------------------------------------------
COPY branding /opt/branding
RUN base64 -d /opt/branding/logo.png.b64 > /opt/branding/logo.png \
    && base64 -d /opt/branding/favicon.ico.b64 > /opt/branding/favicon.ico \
    && rm -f /opt/branding/*.b64

# --- Scripts de operacion ---------------------------------------------------
COPY backup.sh /usr/local/bin/backup.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
