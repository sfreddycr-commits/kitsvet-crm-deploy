#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/var/www/html
cd "$APP_DIR"

log() { printf '[crm] %s\n' "$*"; }

# --- Variables obligatorias ------------------------------------------------
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

# --- 1. Configurar conexión a base de datos --------------------------------
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
    log "ERROR: MySQL no respondió después de 120s. Abortando."
    exit 1
fi
log "MySQL disponible."

# --- 3. Instalación inicial (solo la primera vez) --------------------------
if [ ! -f public/legacy/config.php ]; then
    log "Instalando SuiteCRM (primera ejecución)..."

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

    log "Instalación finalizada."
    chown -R www-data:www-data "$APP_DIR"
fi

# --- 4. Permitir el scheduler al usuario de Apache -------------------------
if [ ! -f public/legacy/config_override.php ]; then
    log "Creando config_override.php (allowed_cron_users)"
    cat > public/legacy/config_override.php <<'PHP'
<?php
// Generado por docker-entrypoint: habilita el scheduler para www-data
$sugar_config['allowed_cron_users'] = ['www-data'];
PHP
fi

# --- 5. Permisos de escritura ---------------------------------------------
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

if [ -f public/legacy/config.php ]; then
    chown www-data:www-data public/legacy/config.php
fi
if [ -f public/legacy/config_override.php ]; then
    chown www-data:www-data public/legacy/config_override.php
fi

# --- 6. Scheduler de SuiteCRM (cada 60 s) ---------------------------------
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
