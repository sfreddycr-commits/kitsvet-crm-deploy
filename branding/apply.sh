#!/usr/bin/env bash
# Branding Kits & Vet CRM sobre una instalacion de SuiteCRM.
# NOTA LEGAL: este script NO altera los avisos de copyright del codigo fuente
# ni elimina el aviso "Supercharged by SuiteCRM", exigido por la GNU AGPL v3,
# seccion 7(b). Solo cambia la capa visual de marca.
set -Eeuo pipefail

APP_DIR="${1:-/var/www/html}"
BRAND_DIR="/opt/branding"
cd "$APP_DIR"

log() { printf '[branding] %s\n' "$*"; }

# --- 1. Titulo del documento ----------------------------------------------
if [ -f public/dist/index.html ]; then
    sed -i 's|<title>SuiteCRM</title>|<title>Kits \& Vet CRM</title>|' public/dist/index.html
    grep -q 'dist/brand.css' public/dist/index.html || \
        sed -i 's|</head>|<link rel="stylesheet" href="dist/brand.css"></head>|' public/dist/index.html
    [ -f "$BRAND_DIR/brand.css" ] && cp -f "$BRAND_DIR/brand.css" public/dist/brand.css
fi

# --- 2. Logos y favicon ----------------------------------------------------
if [ -f "$BRAND_DIR/logo.png" ]; then
    cp -f "$BRAND_DIR/logo.png" public/dist/themes/suite8/images/suitecrm_logo.png
    cp -f "$BRAND_DIR/logo.png" public/legacy/themes/suite8/images/company_logo.png
    cp -f "$BRAND_DIR/logo.png" public/legacy/themes/default/images/company_logo.png
fi
[ -f "$BRAND_DIR/favicon.ico" ] && cp -f "$BRAND_DIR/favicon.ico" public/favicon.ico

# --- 3. Manifiesto PWA -----------------------------------------------------
cat > public/site.webmanifest <<'JSON'
{
    "lang": "es-CR",
    "name": "Kits & Vet CRM",
    "short_name": "KVCRM",
    "description": "CRM de Kits & Vet",
    "start_url": ".",
    "orientation": "portrait",
    "display": "fullscreen",
    "background_color": "#17548B",
    "icons": [{"src": "legacy/themes/default/images/company_logo.png", "sizes": "184x40", "type": "image/png"}]
}
JSON

# --- 4. Paleta: azul marino #17548B / verde #3E8B52 ------------------------
BRAND_SED='s/#534d64/#17548B/gI;s/#778591/#17548B/gI;s/#5d5670/#14456F/gI;s/#6a6578/#2A6BA5/gI;s/#757083/#3D7AB0/gI;s/#9589b3/#7FA6C9/gI;s/#aa9dcc/#A8C4DD/gI;s/#a99ac9/#3E8B52/gI;s/#b29eb5/#C5D8E8/gI;s/#65697a/#4A5F73/gI;s/#337ab7/#17548B/gI;s/#f08377/#3E8B52/gI;s/#d66c60/#2F6B3E/gI;s/#5cb85c/#3E8B52/gI;s/#3c763d/#2F6B3E/gI;s/#6ea674/#5AA46A/gI;s/#79996a/#6BA56F/gI;s/#93a4b3/#9DB4C9/gI;s/#94a6b5/#9DB4C9/gI;s/#808f9c/#7E94A8/gI;s/#7096b5/#5B87AE/gI;s/#a29eab/#8FA6BC/gI;s/#a5e8d6/#D8EDE0/gI;s/#d8f5ee/#E8F3EC/gI;s/#007bff/#17548B/gI'

find public/legacy/themes/suite8/css public/legacy/cache/themes -type f \( -name '*.css' -o -name '*.scss' \) 2>/dev/null | while read -r f; do
    sed -i "$BRAND_SED" "$f" || true
done
for f in public/dist/styles.*.css; do
    [ -f "$f" ] && sed -i "$BRAND_SED" "$f" || true
done

# Scoped contrast corrections, shared by all legacy theme variants.
for f in public/legacy/themes/suite8/css/*/style.css; do
    [ -f "$f" ] || continue
    if ! grep -q 'kv-contrast-v8' "$f"; then
        printf '\n/* kv-contrast-v8 */\n' >> "$f"
        cat "$BRAND_DIR/contrast.css" >> "$f"
    fi
done

# --- 5. Textos de interfaz: nombre del producto ----------------------------
# Solo lineas de valor (se omiten comentarios que empiezan con *), para no
# alterar los avisos de copyright del encabezado de cada archivo.
find public/legacy/include/language public/legacy/modules \
     -type f \( -name 'en_us.lang.php' -o -name 'en_us.notify_template.html' \) 2>/dev/null | while read -r f; do
    case "$f" in
        *.html) sed -i '/^[[:space:]]*\*/!s/SuiteCRM/Kits \&amp; Vet CRM/g' "$f" || true ;;
        *)      sed -i '/^[[:space:]]*\*/!s/SuiteCRM/Kits \& Vet CRM/g' "$f" || true ;;
    esac
done

# --- 6. Nombre del sistema en el shell Angular -----------------------------
for f in public/dist/main.*.js; do
    [ -f "$f" ] && sed -i 's|t="SuiteCRM"|t="Kits \& Vet CRM"|' "$f" || true
done

# --- 7. Invalidar caches ---------------------------------------------------
rm -rf public/legacy/cache/themes/suite8/css \
       public/legacy/cache/themes/suite8/js \
       public/legacy/cache/modules \
       public/legacy/cache/smarty/templates_c

log "branding aplicado"
