#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/var/www/html
cd "$APP_DIR"

log() { printf '[crm] %s\n' "$*"; }

: "${DB_HOST:?DB_HOST es obligatorio}"
: "${DB_NAME:?DB_NAME es obligatorio}"
: "${DB_USER:?DB_USER es obligatorio}"
: "${DB_PASSWORD:?DB_PASSWORD es obligatorio}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD es obligatorio}"

DB_PORT="${DB_PORT:-3306}"
DB_SERVER_VERSION="${DB_SERVER_VERSION:-8.0.36}"
ADMIN_USER="${ADMIN_USER:-admin}"
SITE_URL="${SITE_URL:-http://localhost}"
export APP_ENV="${APP_ENV:-prod}"

DB_URL="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?serverVersion=${DB_SERVER_VERSION}&charset=utf8mb4"

# --- 1. Conexion a base de datos -------------------------------------------
log "Configurando DATABASE_URL -> ${DB_HOST}:${DB_PORT}/${DB_NAME}"
if grep -q '^DATABASE_URL=' .env; then
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"${DB_URL}\"|" .env
else
    printf 'DATABASE_URL="%s"\n' "$DB_URL" >> .env
fi

# --- 2. Esperar a MySQL ----------------------------------------------------
log "Esperando MySQL..."
ready=0
for _ in $(seq 1 60); do
    if php -r '
        try {
            new PDO(
                "mysql:host=" . getenv("DB_HOST") . ";port=" . getenv("DB_PORT") . ";dbname=" . getenv("DB_NAME"),
                getenv("DB_USER"),
                getenv("DB_PASSWORD")
            );
            exit(0);
        } catch (Throwable $e) {
            exit(1);
        }
    ' >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 2
done

if [ "$ready" -ne 1 ]; then
    log "ERROR: MySQL no respondio despues de 120s. Abortando."
    exit 1
fi
log "MySQL disponible."

# --- 3. Instalacion inicial (solo la primera vez) --------------------------
if [ ! -f public/legacy/config.php ]; then
    log "Instalando SuiteCRM (primera ejecucion)..."

    php bin/console suitecrm:app:install \
        -U "$DB_USER" \
        -P "$DB_PASSWORD" \
        -H "$DB_HOST" \
        -Z "$DB_PORT" \
        -N "$DB_NAME" \
        -u "$ADMIN_USER" \
        -p "$ADMIN_PASSWORD" \
        -S "$SITE_URL" \
        -d no \
        -W true \
        --no-interaction

    log "Instalacion finalizada."
    chown -R www-data:www-data "$APP_DIR"
fi

# --- 4. Scheduler: permitir al usuario de Apache ---------------------------
OVERRIDE=public/legacy/config_override.php
if [ -f public/legacy/config.php ] && ! grep -qF "'cron']['allowed_cron_users'" "$OVERRIDE" 2>/dev/null; then
    log "Habilitando cron.allowed_cron_users para www-data"
    if [ ! -f "$OVERRIDE" ]; then
        printf '<?php\n' > "$OVERRIDE"
    fi
    cat >> "$OVERRIDE" <<'PHP'
$sugar_config['cron']['allowed_cron_users'] = ['www-data'];
PHP
fi

# --- 5. Branding Kits & Vet CRM --------------------------------------------
BRAND_DIR=/opt/branding
BRAND_VERSION=v2
BRAND_STAMP="$APP_DIR/.brand-version"
if [ -d "$BRAND_DIR" ] && [ "$(cat "$BRAND_STAMP" 2>/dev/null || true)" != "$BRAND_VERSION" ]; then
    log "Aplicando branding Kits & Vet CRM ($BRAND_VERSION)"

    if [ -f public/dist/index.html ]; then
        sed -i 's|<title>SuiteCRM</title>|<title>Kits \& Vet CRM</title>|' public/dist/index.html
        if ! grep -q 'dist/brand.css' public/dist/index.html; then
            sed -i 's|</head>|<link rel="stylesheet" href="dist/brand.css"></head>|' public/dist/index.html
        fi
        [ -f "$BRAND_DIR/brand.css" ] && cp -f "$BRAND_DIR/brand.css" public/dist/brand.css
    fi

    if [ -f "$BRAND_DIR/logo.png" ]; then
        cp -f "$BRAND_DIR/logo.png" public/dist/themes/suite8/images/suitecrm_logo.png
        cp -f "$BRAND_DIR/logo.png" public/legacy/themes/suite8/images/company_logo.png
        cp -f "$BRAND_DIR/logo.png" public/legacy/themes/default/images/company_logo.png
    fi
    if [ -f "$BRAND_DIR/favicon.ico" ]; then
        cp -f "$BRAND_DIR/favicon.ico" public/favicon.ico
    fi

    # Paleta del tema legacy (azul marino + verde de marca)
    for pal in public/legacy/themes/suite8/css/Dawn/color-palette.scss \
               public/legacy/themes/suite8/css/Noon/color-palette.scss; do
        if [ -f "$pal" ]; then
            sed -i \
                -e 's/#534D64/#17548B/g' \
                -e 's/#534d64/#17548b/g' \
                -e 's/#5D5670/#14456F/g' \
                -e 's/#6A6578/#2A6BA5/g' \
                -e 's/#757083/#3D7AB0/g' \
                -e 's/#9589B3/#7FA6C9/g' \
                -e 's/#AA9DCC/#A8C4DD/g' \
                -e 's/#B29EB5/#C5D8E8/g' \
                -e 's/#778591/#17548B/g' \
                -e 's/#337AB7/#17548B/g' \
                -e 's/#5CB85C/#3E8B52/g' \
                -e 's/#3C763D/#2F6B3E/g' \
                -e 's/#6EA674/#5AA46A/g' \
                -e 's/#79996A/#6BA56F/g' \
                "$pal"
        fi
    done

    # CSS compilado del shell Angular
    for cssf in public/dist/styles.*.css; do
        if [ -f "$cssf" ]; then
            sed -i \
                -e 's/#534D64/#17548B/g' \
                -e 's/#534d64/#17548b/g' \
                -e 's/#EB6657/#17548B/g' \
                -e 's/#eb6657/#17548b/g' \
                -e 's/#007bff/#17548B/g' \
                -e 's/#007BFF/#17548B/g' \
                -e 's/#778591/#4A5F73/g' \
                "$cssf"
        fi
    done

    rm -rf public/legacy/cache/themes/suite8/css public/legacy/cache/themes/suite8/js

    printf '%s' "$BRAND_VERSION" > "$BRAND_STAMP"
fi

# --- 6. Permisos de escritura ---------------------------------------------
for d in . cache logs tmp \
         public/legacy/cache \
         public/legacy/custom \
         public/legacy/upload \
         public/legacy/themes; do
    if [ -d "$APP_DIR/$d" ]; then
        chown -R www-data:www-data "$APP_DIR/$d"
        chmod -R g+rwX "$APP_DIR/$d"
    fi
done

for f in public/legacy/config.php "$OVERRIDE" "$BRAND_STAMP"; do
    if [ -f "$f" ]; then chown www-data:www-data "$f"; fi
done

# --- 7. Scheduler de SuiteCRM (cada 60 s) ---------------------------------
if [ "${CRM_CRON_ENABLED:-true}" = "true" ]; then
    log "Iniciando scheduler de SuiteCRM (60s)"
    (
        while true; do
            su -s /bin/sh www-data -c "cd $APP_DIR && php bin/console schedulers:run" \
                >> "$APP_DIR/logs/cron.log" 2>&1 || true
            sleep 60
        done
    ) &
fi

log "Iniciando Apache."
exec "$@"
