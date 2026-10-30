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
BRAND_VERSION=v4
BRAND_STAMP="$APP_DIR/.brand-version"
# azul marino #17548B / verde #3E8B52
BRAND_SED='s/#534d64/#17548B/gI;s/#778591/#17548B/gI;s/#5d5670/#14456F/gI;s/#6a6578/#2A6BA5/gI;s/#757083/#3D7AB0/gI;s/#9589b3/#7FA6C9/gI;s/#aa9dcc/#A8C4DD/gI;s/#b29eb5/#C5D8E8/gI;s/#337ab7/#17548B/gI;s/#f08377/#3E8B52/gI;s/#5cb85c/#3E8B52/gI;s/#3c763d/#2F6B3E/gI;s/#6ea674/#5AA46A/gI;s/#79996a/#6BA56F/gI;s/#93a4b3/#9DB4C9/gI;s/#94a6b5/#9DB4C9/gI;s/#808f9c/#7E94A8/gI;s/#7096b5/#5B87AE/gI;s/#a29eab/#8FA6BC/gI;s/#007bff/#17548B/gI'

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

    # Tema legacy: SCSS fuente y CSS compilado
    find public/legacy/themes/suite8/css public/legacy/cache/themes -type f \( -name '*.css' -o -name '*.scss' \) 2>/dev/null | while read -r f; do
        sed -i "$BRAND_SED" "$f" || true
    done
    # CSS compilado del shell Angular
    for f in public/dist/styles.*.css; do
        [ -f "$f" ] && sed -i "$BRAND_SED" "$f" || true
    done

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
