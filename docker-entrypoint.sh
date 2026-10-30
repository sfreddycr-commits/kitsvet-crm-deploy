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

log "Configurando DATABASE_URL -> ${DB_HOST}:${DB_PORT}/${DB_NAME}"
if grep -q '^DATABASE_URL=' .env; then
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"${DB_URL}\"|" .env
else
    printf 'DATABASE_URL="%s"\n' "$DB_URL" >> .env
fi

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

if [ ! -f public/legacy/config.php ]; then
    log "Instalando SuiteCRM (primera ejecucion)..."
    php bin/console suitecrm:app:install \
        -U "$DB_USER" -P "$DB_PASSWORD" -H "$DB_HOST" -Z "$DB_PORT" -N "$DB_NAME" \
        -u "$ADMIN_USER" -p "$ADMIN_PASSWORD" -S "$SITE_URL" -d no -W true \
        --no-interaction
    log "Instalacion finalizada."
    chown -R www-data:www-data "$APP_DIR"
fi

OVERRIDE=public/legacy/config_override.php
if [ -f public/legacy/config.php ] && ! grep -qF "'cron']['allowed_cron_users'" "$OVERRIDE" 2>/dev/null; then
    log "Habilitando cron.allowed_cron_users para www-data"
    [ -f "$OVERRIDE" ] || printf '<?php\n' > "$OVERRIDE"
    printf '%s\n' "\$sugar_config['cron']['allowed_cron_users'] = ['www-data'];" >> "$OVERRIDE"
fi

# --- Branding --------------------------------------------------------------
BRAND_DIR=/opt/branding
BRAND_VERSION=v7
BRAND_STAMP="$APP_DIR/.brand-version"
if [ -d "$BRAND_DIR" ] && [ -f "$BRAND_DIR/apply.sh" ] \
   && [ "$(cat "$BRAND_STAMP" 2>/dev/null || true)" != "$BRAND_VERSION" ]; then
    log "Aplicando branding Kits & Vet CRM ($BRAND_VERSION)"
    bash "$BRAND_DIR/apply.sh" "$APP_DIR"
    printf '%s' "$BRAND_VERSION" > "$BRAND_STAMP"
fi

# --- Permisos --------------------------------------------------------------
for d in . cache logs tmp public/legacy/cache public/legacy/custom public/legacy/upload public/legacy/themes; do
    if [ -d "$APP_DIR/$d" ]; then
        chown -R www-data:www-data "$APP_DIR/$d"
        chmod -R g+rwX "$APP_DIR/$d"
    fi
done
for f in public/legacy/config.php "$OVERRIDE" "$BRAND_STAMP"; do
    [ -f "$f" ] && chown www-data:www-data "$f"
done

# --- Scheduler -------------------------------------------------------------
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

# --- Respaldos -------------------------------------------------------------
if [ "${CRM_BACKUP_ENABLED:-true}" = "true" ]; then
    log "Respaldos activos (retencion BD ${RETENTION_DAYS:-14} dias)"
    (
        while true; do
            if [ -z "$(find /var/backups/crm -type f -name 'db-*.sql.gz' -mtime -1 2>/dev/null | head -1)" ]; then
                bash /usr/local/bin/backup.sh now >> "$APP_DIR/logs/backup.log" 2>&1 || true
            fi
            sleep 3600
        done
    ) &
fi

log "Iniciando Apache."
exec "$@"
