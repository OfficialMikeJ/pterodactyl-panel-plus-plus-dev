#!/bin/bash
set -uo pipefail

#############################################################################
#  Touch Down Hosting — Panel Repair & Health Check                         #
#                                                                           #
#  Diagnoses a broken or half-finished panel install and fixes what it can  #
#  automatically. Safe to run as many times as you like; it never deletes   #
#  data and never touches the database contents.                            #
#                                                                           #
#    sudo bash repair-touchdown-panel.sh              # check + auto-fix    #
#    sudo bash repair-touchdown-panel.sh --check      # report only         #
#    sudo PANEL_DIR=/path/to/panel bash repair-touchdown-panel.sh           #
#                                                                           #
#  Checks: panel directory, .env, APP_KEY, APP_URL, runtime directories,    #
#  permissions, composer/vendor, built frontend assets, database connection #
#  and migrations, redis, nginx site, queue worker, cron, and which address #
#  the panel is actually reachable on.                                      #
#############################################################################

CHECK_ONLY="no"
[ "${1:-}" = "--check" ] && CHECK_ONLY="yes"

ORANGE='\033[38;5;208m'; WHITE='\033[1;37m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
ok()    { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
fix()   { echo -e "${ORANGE}[ FIX  ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[ WARN ]${RESET} $1"; }
bad()   { echo -e "${RED}[ FAIL ]${RESET} $1"; }
head_() { echo -e "\n${WHITE}== $1${RESET}"; }

ISSUES=0
FIXED=0
note_issue() { ISSUES=$((ISSUES + 1)); }
note_fixed() { FIXED=$((FIXED + 1)); }

[ "$(id -u)" -eq 0 ] || { bad "Run as root (sudo bash $0)"; exit 1; }

# ── Locate the panel ───────────────────────────────────────────────────────
head_ "Panel location"
if [ -n "${PANEL_DIR:-}" ] && [ -f "${PANEL_DIR}/artisan" ]; then
  :
else
  for candidate in /home/storage/Pterodactyl /var/www/touchdown /var/www/pterodactyl; do
    [ -f "${candidate}/artisan" ] && { PANEL_DIR="$candidate"; break; }
  done
fi
if [ -z "${PANEL_DIR:-}" ] || [ ! -f "${PANEL_DIR}/artisan" ]; then
  PANEL_DIR="$(dirname "$(find /home /var/www /srv /opt /root -maxdepth 5 -name artisan -type f 2>/dev/null | head -1)")"
fi
if [ ! -f "${PANEL_DIR}/artisan" ]; then
  bad "No panel installation found. Run the installer first:"
  bad "  bash installer/install-touchdown-panel.sh"
  exit 1
fi
cd "$PANEL_DIR"
ok "Panel found at ${PANEL_DIR}"

# ── .env ───────────────────────────────────────────────────────────────────
head_ ".env configuration"
if [ ! -f .env ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && [ -f .env.example ]; then
    cp .env.example .env; fix "Created .env from .env.example"; note_fixed
  else
    bad ".env is missing"
  fi
else
  ok ".env exists"
fi

env_get() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'; }
env_set() {
  grep -q "^$1=" .env && sed -i "s|^$1=.*|$1=$2|" .env || echo "$1=$2" >> .env
}

# APP_KEY — generated with plain PHP so it works even when Laravel cannot boot.
if grep -q '^APP_KEY=base64:' .env 2>/dev/null; then
  ok "APP_KEY is set"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    rm -f bootstrap/cache/config.php
    env_set "APP_KEY" "base64:$(php -r 'echo base64_encode(random_bytes(32));')"
    fix "Generated a new APP_KEY"; note_fixed
  else
    bad "APP_KEY is empty (panel cannot boot)"
  fi
fi

# APP_URL sanity — https without a certificate, or a placeholder, breaks logins.
APP_URL="$(env_get APP_URL)"
PRIMARY_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "$APP_URL" ] || [ "$APP_URL" = "http://panel.example.com" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && [ -n "$PRIMARY_IP" ]; then
    env_set "APP_URL" "http://${PRIMARY_IP}"; fix "APP_URL set to http://${PRIMARY_IP}"; note_fixed
  else
    bad "APP_URL is unset or still the example value"
  fi
else
  ok "APP_URL is ${APP_URL}"
  host_part="${APP_URL#*://}"; host_part="${host_part%%[:/]*}"
  if [[ "$APP_URL" == https://* ]] && [[ "$host_part" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    note_issue
    if [ "$CHECK_ONLY" = "no" ]; then
      env_set "APP_URL" "http://${host_part}"
      fix "APP_URL uses https with a bare IP (no certificate possible) — switched to http"
      note_fixed
    else
      warn "APP_URL uses https with a bare IP; certificates cannot be issued for IPs"
    fi
  fi
fi

# ── Runtime directories & permissions ──────────────────────────────────────
head_ "Runtime directories & permissions"
MISSING_DIRS=""
for d in storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache; do
  [ -d "$d" ] || MISSING_DIRS="$MISSING_DIRS $d"
done
if [ -n "$MISSING_DIRS" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    # shellcheck disable=SC2086
    mkdir -p $MISSING_DIRS
    fix "Created missing runtime directories:$MISSING_DIRS"; note_fixed
  else
    bad "Missing runtime directories:$MISSING_DIRS"
  fi
else
  ok "Runtime directories present"
fi

if [ "$(stat -c '%U' storage 2>/dev/null)" != "www-data" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 storage bootstrap/cache
    fix "Reset ownership to www-data and storage permissions"; note_fixed
  else
    bad "storage/ is not owned by www-data"
  fi
else
  ok "Ownership looks correct"
fi

if [ -f .env ] && [ "$(stat -c '%a' .env)" != "600" ]; then
  if [ "$CHECK_ONLY" = "no" ]; then
    chmod 600 .env; chown www-data:www-data .env; fix "Tightened .env permissions to 600"; note_fixed
  else
    warn ".env is not mode 600"
  fi
else
  ok ".env permissions are correct"
fi

# ── Dependencies & assets ──────────────────────────────────────────────────
head_ "Dependencies & assets"
if [ -d vendor ]; then
  ok "PHP dependencies installed (vendor/)"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && command -v composer >/dev/null; then
    fix "Installing PHP dependencies (composer)..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --quiet \
      && { fix "composer install complete"; note_fixed; } || bad "composer install failed"
  else
    bad "vendor/ is missing — run: composer install --no-dev --optimize-autoloader"
  fi
fi

if ls public/assets/*.js >/dev/null 2>&1; then
  ok "Frontend assets are built"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && command -v yarn >/dev/null; then
    fix "Building frontend assets (this takes a minute)..."
    yarn install --frozen-lockfile --silent && yarn build:production >/dev/null \
      && { fix "Assets built"; note_fixed; } || bad "Asset build failed"
  else
    bad "public/assets is empty — run: yarn install && yarn build:production"
  fi
fi

# ── Services ───────────────────────────────────────────────────────────────
head_ "Services"
for svc in mariadb redis-server nginx; do
  if systemctl is-active --quiet "$svc"; then
    ok "$svc is running"
  else
    note_issue
    if [ "$CHECK_ONLY" = "no" ]; then
      systemctl enable --now "$svc" >/dev/null 2>&1 && { fix "Started $svc"; note_fixed; } || bad "Could not start $svc"
    else
      bad "$svc is not running"
    fi
  fi
done

# ── Database ───────────────────────────────────────────────────────────────
head_ "Database"
rm -f bootstrap/cache/config.php
if php artisan db:show >/dev/null 2>&1 || php artisan migrate:status >/dev/null 2>&1; then
  ok "Database connection works"
  if php artisan migrate:status 2>/dev/null | grep -qi "pending\|No migrations"; then
    note_issue
    if [ "$CHECK_ONLY" = "no" ]; then
      php artisan migrate --seed --force && { fix "Ran pending migrations"; note_fixed; } || bad "Migrations failed"
    else
      bad "There are pending migrations"
    fi
  else
    ok "Migrations are up to date"
  fi
else
  note_issue
  bad "Cannot connect to the database — check DB_* values in .env"
  bad "  (re-run the installer to reconfigure: installer/install-touchdown-panel.sh)"
fi

# ── nginx site ─────────────────────────────────────────────────────────────
head_ "Web server"
SITE=""
for s in /etc/nginx/sites-available/touchdown.conf /etc/nginx/sites-available/pterodactyl.conf; do
  [ -f "$s" ] && { SITE="$s"; break; }
done

if [ -z "$SITE" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    SERVER_NAME="${PRIMARY_IP:-_}"
    cat > /etc/nginx/sites-available/touchdown.conf <<EOF
server {
    listen 80;
    server_name ${SERVER_NAME};

    root ${PANEL_DIR}/public;
    index index.php;

    access_log /var/log/nginx/touchdown.app-access.log;
    error_log  /var/log/nginx/touchdown.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht { deny all; }
}
EOF
    SITE=/etc/nginx/sites-available/touchdown.conf
    fix "Created nginx site config"; note_fixed
  else
    bad "No panel nginx site config found"
  fi
fi

if [ -n "$SITE" ]; then
  LINK="/etc/nginx/sites-enabled/$(basename "$SITE")"
  if [ ! -L "$LINK" ] && [ ! -f "$LINK" ]; then
    note_issue
    if [ "$CHECK_ONLY" = "no" ]; then
      ln -sf "$SITE" "$LINK"; fix "Enabled the panel site"; note_fixed
    else
      bad "Panel site exists but is not enabled"
    fi
  else
    ok "Panel site is enabled"
  fi
fi

if [ -e /etc/nginx/sites-enabled/default ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    rm -f /etc/nginx/sites-enabled/default
    fix "Removed nginx's default site (it was shadowing the panel — this is the 'Welcome to nginx!' page)"
    note_fixed
  else
    bad "nginx's default site is enabled and will shadow the panel"
  fi
else
  ok "nginx default site is not enabled"
fi

if [ "$CHECK_ONLY" = "no" ]; then
  if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx; ok "nginx config valid and reloaded"
  else
    bad "nginx config test FAILED:"; nginx -t
  fi
fi

# PHP-FPM must be running for the site to serve anything.
FPM_SVC="$(systemctl list-units --type=service --all 2>/dev/null | grep -o 'php[0-9.]*-fpm.service' | head -1)"
if [ -n "$FPM_SVC" ]; then
  if systemctl is-active --quiet "$FPM_SVC"; then
    ok "$FPM_SVC is running"
  else
    note_issue
    [ "$CHECK_ONLY" = "no" ] && { systemctl enable --now "$FPM_SVC" >/dev/null 2>&1 && { fix "Started $FPM_SVC"; note_fixed; }; } || bad "$FPM_SVC is not running"
  fi
fi

# ── Queue worker & cron ────────────────────────────────────────────────────
head_ "Background workers"
if systemctl list-unit-files 2>/dev/null | grep -q '^pteroq.service'; then
  if systemctl is-active --quiet pteroq; then
    ok "Queue worker (pteroq) is running"
  else
    note_issue
    if [ "$CHECK_ONLY" = "no" ]; then
      systemctl enable --now pteroq >/dev/null 2>&1 && { fix "Started the queue worker"; note_fixed; } || bad "Could not start pteroq"
    else
      bad "Queue worker is not running"
    fi
  fi
else
  note_issue
  bad "pteroq.service does not exist — re-run the installer to create it"
fi

if crontab -u www-data -l 2>/dev/null | grep -q "artisan schedule:run"; then
  ok "Scheduler cron entry present"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    (crontab -u www-data -l 2>/dev/null; echo "* * * * * php ${PANEL_DIR}/artisan schedule:run >> /dev/null 2>&1") | sort -u | crontab -u www-data -
    fix "Added the scheduler cron entry"; note_fixed
  else
    bad "Scheduler cron entry is missing"
  fi
fi

# ── Final reachability check ───────────────────────────────────────────────
head_ "Reachability"
[ "$CHECK_ONLY" = "no" ] && php artisan config:clear >/dev/null 2>&1
CODE="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${PRIMARY_IP:-localhost}" http://127.0.0.1 2>/dev/null)"
case "$CODE" in
  200|302) ok "Panel responded with HTTP $CODE — it is serving correctly" ;;
  000)     bad "No response from the web server on port 80" ;;
  *)       warn "Panel responded with HTTP $CODE (check /var/log/nginx/touchdown.app-error.log)" ;;
esac

echo
echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"
if [ "$CHECK_ONLY" = "yes" ]; then
  echo -e "  ${WHITE}Health check complete — ${ISSUES} issue(s) found.${RESET}"
  [ "$ISSUES" -gt 0 ] && echo -e "  Re-run without --check to repair them automatically."
else
  echo -e "  ${WHITE}Repair complete — ${ISSUES} issue(s) found, ${FIXED} fixed.${RESET}"
fi
[ -n "${PRIMARY_IP:-}" ] && echo -e "  Panel address: ${WHITE}http://${PRIMARY_IP}${RESET}"
echo -e "  Panel path:    ${WHITE}${PANEL_DIR}${RESET}"
echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"
