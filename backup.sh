#!/usr/bin/env bash
# Respaldo de la base de datos y de los archivos subidos del CRM.
# Uso: backup.sh [now|db|files]
set -Eeuo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/crm}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
FILES_RETENTION="${FILES_RETENTION:-28}"
APP_DIR="${APP_DIR:-/var/www/html}"

log() { printf '[backup] %s\n' "$*"; }
mkdir -p "$BACKUP_DIR"

ts=$(date -u +%Y%m%d-%H%M)

db_backup() {
    local out="$BACKUP_DIR/db-$ts.sql.gz"
    : "${DB_HOST:?}" ; : "${DB_NAME:?}" ; : "${DB_USER:?}" ; : "${DB_PASSWORD:?}"
    if mysqldump -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASSWORD" \
            --single-transaction --quick --routines --triggers --events \
            --default-character-set=utf8mb4 "$DB_NAME" 2>/dev/null | gzip -9 > "$out"; then
        log "BD: $(basename "$out") ($(du -h "$out" | cut -f1))"
    else
        rm -f "$out"
        log "ERROR: no se pudo respaldar la base de datos"
        return 1
    fi
}

files_backup() {
    local out="$BACKUP_DIR/files-$ts.tar.gz"
    tar -czf "$out" -C "$APP_DIR/public/legacy" upload custom 2>/dev/null || true
    if [ -s "$out" ]; then
        log "Archivos: $(basename "$out") ($(du -h "$out" | cut -f1))"
    else
        rm -f "$out"
        log "Archivos: nada que respaldar"
    fi
}

rotate() {
    find "$BACKUP_DIR" -type f -name 'db-*.sql.gz' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    find "$BACKUP_DIR" -type f -name 'files-*.tar.gz' -mtime +"$FILES_RETENTION" -delete 2>/dev/null || true
}

case "${1:-now}" in
    db)    db_backup; rotate ;;
    files) files_backup; rotate ;;
    now)   db_backup; rotate ;;
    *)     log "uso: backup.sh [now|db|files]"; exit 2 ;;
esac
