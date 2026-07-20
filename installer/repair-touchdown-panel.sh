#!/bin/bash
set -uo pipefail

#############################################################################
#  Touch Down Hosting — Panel Repair & Health Check                         #
#                                                                           #
#  Diagnoses a broken or half-finished panel install and fixes what it can. #
#  Every repair is verified by re-running its check, so a [ FIX ] line      #
#  means the problem is actually gone — not merely that a command ran.      #
#                                                                           #
#    sudo bash repair-touchdown-panel.sh              # check + auto-fix    #
#    sudo bash repair-touchdown-panel.sh --check      # report only         #
#    sudo bash repair-touchdown-panel.sh --seed       # also import eggs    #
#    sudo PANEL_DIR=/path/to/panel bash repair-touchdown-panel.sh           #
#                                                                           #
#  Exits non-zero if anything could not be repaired.                        #
#                                                                           #
#  It never deletes data, never seeds the database unless --seed is given,  #
#  never rotates APP_KEY over existing data, and moves (never deletes)      #
#  nginx configs it has to disable.                                         #
#############################################################################

CHECK_ONLY="no"
ALLOW_SEED="no"
FORCE_KEY="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--dry-run) CHECK_ONLY="yes" ;;
    --seed)            ALLOW_SEED="yes" ;;
    --force-key)       FORCE_KEY="yes" ;;
    -h|--help)         sed -n '4,20p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1 (valid: --check, --seed, --force-key)" >&2; exit 2 ;;
  esac
  shift
done

ORANGE='\033[38;5;208m'; WHITE='\033[1;37m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
ok()    { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
fix()   { echo -e "${ORANGE}[ FIX  ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[ WARN ]${RESET} $1"; }
bad()   { echo -e "${RED}[ FAIL ]${RESET} $1"; }
head_() { echo -e "\n${WHITE}== $1${RESET}"; }
detail(){ echo "         $1"; }

ISSUES=0; FIXED=0; UNRESOLVED=0
note_issue()      { ISSUES=$((ISSUES + 1)); }
note_fixed()      { FIXED=$((FIXED + 1)); }
note_unresolved() { UNRESOLVED=$((UNRESOLVED + 1)); }

# repair_step <label> <predicate_fn> <repair_fn>
# The predicate must be side-effect free and re-runnable; it is evaluated
# again after the repair, and only a passing re-check reports success.
repair_step() {
  local label="$1" pred="$2" rep="$3"
  if "$pred"; then ok "$label"; return 0; fi
  note_issue
  if [ "$CHECK_ONLY" = "yes" ]; then
    bad "$label — needs repair"; note_unresolved; return 1
  fi
  "$rep"
  if "$pred"; then
    fix "$label — repaired and verified"; note_fixed; return 0
  fi
  bad "$label — repair attempted but verification STILL FAILS"; note_unresolved; return 1
}

[ "$(id -u)" -eq 0 ] || { bad "Run as root (sudo bash $0)"; exit 1; }

# runuser (util-linux) avoids sudoers/PAM and works with nologin shells.
if command -v runuser >/dev/null 2>&1; then
  as_user() { runuser -u "$1" -- "${@:2}"; }
else
  as_user() { sudo -n -u "$1" "${@:2}"; }
fi

# ── 1. Resolve the panel directory ─────────────────────────────────────────
head_ "Panel location"
resolve_panel_dir() {
  local found count script_dir
  if [ -n "${PANEL_DIR:-}" ] && [ -f "${PANEL_DIR}/artisan" ]; then
    PANEL_DIR="$(cd "$PANEL_DIR" && pwd -P)"; return 0
  fi
  # Prefer the tree this script lives in (installer/ sits inside the panel).
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  if [ -f "$(dirname "$script_dir")/artisan" ]; then
    PANEL_DIR="$(dirname "$script_dir")"; return 0
  fi
  found="$(find /home /var/www /srv /opt -maxdepth 5 -name artisan -type f \
            -not -path '*/vendor/*' -not -path '*/node_modules/*' 2>/dev/null | sort)"
  count="$(printf '%s\n' "$found" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    bad "No panel installation found. Run: bash installer/install-touchdown-panel.sh"; exit 1
  fi
  if [ "$count" -gt 1 ]; then
    bad "Multiple panel installs found — set PANEL_DIR explicitly:"
    printf '         %s\n' $found
    exit 1
  fi
  PANEL_DIR="$(cd "$(dirname "$found")" && pwd -P)"
}
resolve_panel_dir
case "$PANEL_DIR" in /|"") bad "Refusing to operate on '$PANEL_DIR'"; exit 1 ;; esac
case "$PANEL_DIR" in *[[:space:]]*) bad "PANEL_DIR contains whitespace; nginx/systemd/cron cannot quote it safely"; exit 1 ;; esac
cd "$PANEL_DIR" || { bad "Cannot cd into $PANEL_DIR"; exit 1; }
ok "Panel found at ${PANEL_DIR}"
WANT_ROOT="${PANEL_DIR}/public"

# ── 2. Discover php-fpm service, pool user and listener ────────────────────
head_ "PHP-FPM discovery"
discover_fpm() {
  local v rt lst
  v="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)"
  [ -n "$v" ] && [ -d "/etc/php/${v}/fpm" ] || v=""
  [ -n "$v" ] || v="$(ls -1d /etc/php/*/fpm 2>/dev/null | awk -F/ '{print $4}' | sort -V | tail -1)"
  PHP_VER="$v"

  FPM_SVC=""
  if [ -n "$PHP_VER" ] && systemctl list-unit-files 2>/dev/null | grep -q "^php${PHP_VER}-fpm.service"; then
    FPM_SVC="php${PHP_VER}-fpm.service"
  fi
  [ -n "$FPM_SVC" ] || FPM_SVC="$(systemctl list-unit-files --type=service 2>/dev/null \
      | grep -o 'php[0-9.]*-fpm\.service' | sort -V | tail -1)"

  FPM_POOL="/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
  FPM_USER="$(awk -F= '/^[[:space:]]*user[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2;exit}' "$FPM_POOL" 2>/dev/null)"
  rt="$(ps -eo user:32,args 2>/dev/null | awk '/php-fpm.*pool/ && !/awk/{print $1; exit}')"
  [ -n "$rt" ] && [ "$rt" != "root" ] && FPM_USER="$rt"
  FPM_USER="${FPM_USER:-www-data}"

  lst="$(awk -F= '/^[[:space:]]*listen[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/,"");print;exit}' "$FPM_POOL" 2>/dev/null)"
  FPM_SOCK=""; FPM_TARGET=""
  case "$lst" in
    /*) FPM_SOCK="$lst"; FPM_TARGET="unix:${lst}" ;;
    "") FPM_SOCK="$(ls -1 /run/php/php*-fpm.sock 2>/dev/null | sort -V | tail -1)"
        [ -n "$FPM_SOCK" ] && FPM_TARGET="unix:${FPM_SOCK}" ;;
    *)  case "$lst" in
          *:*) FPM_TARGET="$lst" ;;
          *)   FPM_TARGET="127.0.0.1:${lst}" ;;
        esac ;;
  esac

  NGINX_USER="$(awk '$1=="user"{v=$2; sub(/;.*/,"",v); print v; exit}' /etc/nginx/nginx.conf 2>/dev/null)"
  NGINX_USER="${NGINX_USER:-www-data}"

  # Resolve a PHP binary that actually exists. systemd and cron need an
  # absolute path, and a wrong one fails with 203/EXEC (service never starts).
  PHP_BIN=""
  for cand in "/usr/bin/php${PHP_VER}" "$(command -v "php${PHP_VER}" 2>/dev/null)" "$(command -v php 2>/dev/null)" /usr/bin/php; do
    [ -n "$cand" ] && [ -x "$cand" ] && { PHP_BIN="$cand"; break; }
  done
  if [ -z "$PHP_BIN" ]; then
    note_issue; note_unresolved
    bad "No usable PHP binary found — install php${PHP_VER:-8.3}-cli"
    PHP_BIN="/usr/bin/php"
  fi

  if [ -z "$FPM_SVC" ]; then
    note_issue; note_unresolved
    bad "No php-fpm service found — the panel cannot serve PHP. Install php${PHP_VER:-8.3}-fpm."
  fi
  ok "php-fpm: svc=${FPM_SVC:-none} user=${FPM_USER} listen=${FPM_TARGET:-none} | nginx worker=${NGINX_USER}"
  ok "PHP binary: ${PHP_BIN}"
}
discover_fpm

PRIMARY_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
PRIMARY_IP="${PRIMARY_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
ok "Primary address: ${PRIMARY_IP:-unknown}"

# ── 3. Access proof: can the web server actually READ index.php? ───────────
head_ "Web server access to the panel files"

if [ ! -f "${WANT_ROOT}/index.php" ]; then
  note_issue; note_unresolved
  bad "${WANT_ROOT}/index.php does not exist — the install never completed."
  bad "Run: bash ${PANEL_DIR}/installer/install-touchdown-panel.sh"
fi

fpm_can_read_index() { as_user "$FPM_USER" test -r "${WANT_ROOT}/index.php" 2>/dev/null; }

report_access_evidence() {
  local out
  out="$(as_user "$FPM_USER" cat "${WANT_ROOT}/index.php" 2>&1 >/dev/null)"
  [ -n "$out" ] && detail "as ${FPM_USER}: ${out}"
}

# Superset test: runs inside php-fpm's own mount namespace, so it also catches
# systemd sandboxing (ProtectHome) that a plain runuser test cannot see.
fpm_can_read_index_in_ns() {
  local pid
  pid="$(systemctl show -p MainPID --value "$FPM_SVC" 2>/dev/null)"
  [ -n "$pid" ] && [ "$pid" != "0" ] || return 0
  command -v nsenter >/dev/null 2>&1 || return 0
  nsenter -t "$pid" -m -- test -r "${WANT_ROOT}/index.php" 2>/dev/null
}

if fpm_can_read_index; then
  ok "${FPM_USER} can read ${WANT_ROOT}/index.php"
else
  bad "${FPM_USER} CANNOT read ${WANT_ROOT}/index.php — this is the 'File not found.' cause"
  report_access_evidence
fi

# ── 4. Traversal permissions on every parent directory ─────────────────────
ancestors_of() {
  local p="$1" acc="" seg IFS=/
  printf '/\n'
  for seg in $p; do
    [ -z "$seg" ] && continue
    acc="${acc}/${seg}"
    printf '%s\n' "$acc"
  done
}

traversal_ok() {
  local d
  while read -r d; do
    [ -e "$d" ] || return 1
    as_user "$FPM_USER"   test -x "$d" 2>/dev/null || return 1
    as_user "$NGINX_USER" test -x "$d" 2>/dev/null || return 1
  done < <(ancestors_of "$WANT_ROOT")
  fpm_can_read_index
}

repair_traversal() {
  local d mode changed=0
  while read -r d; do
    [ -d "$d" ] || continue
    if as_user "$FPM_USER" test -x "$d" 2>/dev/null && as_user "$NGINX_USER" test -x "$d" 2>/dev/null; then
      continue
    fi
    mode="$(stat -c '%a %U:%G' "$d" 2>/dev/null)"
    # Preferred: grant traverse to the two service users only, leaving the mode alone.
    if command -v setfacl >/dev/null 2>&1 \
       && setfacl -m "u:${FPM_USER}:--x" "$d" 2>/dev/null \
       && setfacl -m "u:${NGINX_USER}:--x" "$d" 2>/dev/null; then
      detail "ACL: granted traverse (--x) to ${FPM_USER} and ${NGINX_USER} on ${d} (was ${mode}; mode unchanged)"
      changed=1
    elif chmod o+x "$d" 2>/dev/null; then
      detail "chmod o+x ${d}: ${mode} -> $(stat -c '%a' "$d") (traverse only; contents stay unlistable)"
      changed=1
    else
      bad "Could not grant traverse on ${d} (was ${mode})"
    fi
  done < <(ancestors_of "$WANT_ROOT")
  if [ "$changed" -eq 1 ]; then
    detail "Cause: a parent directory denied path resolution to the web server user."
    detail "Ubuntu >=21.04 / Debian >=12 create home directories mode 0750, so a panel"
    detail "under /home is unreachable by ${FPM_USER} until traverse is granted."
  fi
  return 0
}

repair_step "Web server can traverse to ${WANT_ROOT}" traversal_ok repair_traversal

# ── 5. systemd sandboxing (ProtectHome / ProtectSystem) ────────────────────
sandbox_ok() {
  local u ph ps ip
  for u in "$FPM_SVC" nginx.service; do
    [ -n "$u" ] || continue
    ph="$(systemctl show -p ProtectHome --value "$u" 2>/dev/null)"
    ps="$(systemctl show -p ProtectSystem --value "$u" 2>/dev/null)"
    ip="$(systemctl show -p InaccessiblePaths --value "$u" 2>/dev/null)"
    case "$ph" in ""|no) ;; *) return 1 ;; esac
    [ "$ps" = "strict" ] && return 1
    case "$ip" in *"/home"*) return 1 ;; esac
  done
  fpm_can_read_index_in_ns
}

repair_sandbox() {
  local u dir
  for u in "$FPM_SVC" nginx.service; do
    [ -n "$u" ] || continue
    dir="/etc/systemd/system/${u}.d"
    install -d "$dir"
    # ProtectHome/ProtectSystem are scalars (a drop-in overrides them);
    # ReadWritePaths is a list, so it must be cleared before being set.
    # The leading '-' makes a missing path non-fatal — without it the unit
    # refuses to start, turning a broken panel into a dead web server.
    cat > "${dir}/zz-touchdown-panel-path.conf" <<EOF
# Written by repair-touchdown-panel.sh — the panel lives at ${PANEL_DIR}.
# ProtectHome=/ProtectSystem=strict would hide or freeze that path inside this
# service's private mount namespace, producing php-fpm's "File not found."
# even when filesystem permissions are perfect.
[Service]
ProtectHome=no
ReadWritePaths=
ReadWritePaths=-${PANEL_DIR}
EOF
    detail "Wrote ${dir}/zz-touchdown-panel-path.conf (ProtectHome=no)"
  done
  systemctl daemon-reload
  # Namespace settings apply only on restart, never reload.
  [ -n "$FPM_SVC" ] && systemctl restart "$FPM_SVC" 2>/dev/null
  systemctl restart nginx 2>/dev/null
  return 0
}

repair_step "php-fpm/nginx are not sandboxed away from ${PANEL_DIR}" sandbox_ok repair_sandbox

# ── 6. PHP path restrictions (report only — deliberate hardening) ──────────
head_ "PHP restrictions"
PHP_RESTRICT="$(grep -rhE '^[[:space:]]*(php_admin_value\[open_basedir\]|php_value\[open_basedir\]|chroot|security\.limit_extensions)' \
    "/etc/php/${PHP_VER}/fpm/pool.d/" 2>/dev/null)"
PHP_RESTRICT="${PHP_RESTRICT}$(grep -rhE '^[[:space:]]*open_basedir' \
    "/etc/php/${PHP_VER}/fpm/php.ini" "/etc/php/${PHP_VER}/fpm/conf.d/" 2>/dev/null)"
if [ -n "$PHP_RESTRICT" ]; then
  note_issue; note_unresolved
  bad "PHP path restrictions are configured — these can hide ${PANEL_DIR} from php-fpm:"
  printf '         %s\n' $PHP_RESTRICT
  bad "  open_basedir must include '${PANEL_DIR}/' (trailing slash — it is a prefix match)"
  bad "  Not auto-edited: this is a deliberate hardening choice and other pools may share the file."
else
  ok "No open_basedir/chroot restrictions found"
fi
aa-status 2>/dev/null | grep -qiE 'nginx|php|fpm' && warn "An AppArmor profile is loaded for nginx/php — check: dmesg -T | grep DENIED"
command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ] && warn "SELinux is enforcing (unexpected on Debian/Ubuntu)"

# Hard stop: nothing downstream can help if the files are still unreadable.
if [ "$CHECK_ONLY" = "no" ] && [ -f "${WANT_ROOT}/index.php" ] && ! fpm_can_read_index; then
  echo
  bad "${FPM_USER} still cannot read the panel files — stopping here, later steps cannot help."
  report_access_evidence
  bad "Inspect: namei -l ${WANT_ROOT}/index.php"
  exit 1
fi

# ── 7. Environment file ────────────────────────────────────────────────────
head_ ".env configuration"
if [ ! -f .env ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && [ -f .env.example ]; then
    cp .env.example .env; fix "Created .env from .env.example"; note_fixed
  else
    bad ".env is missing"; note_unresolved
  fi
fi

env_get() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d '\r'; }
env_set() {
  local k="$1" v="$2" esc
  esc="$(printf '%s' "$v" | sed -e 's/[&|\\]/\\&/g')"
  if grep -q "^${k}=" .env 2>/dev/null; then
    sed -i "s|^${k}=.*|${k}=${esc}|" .env
  else
    printf '%s=%s\n' "$k" "$v" >> .env
  fi
  [ "$(env_get "$k")" = "$v" ] || { bad "Failed to set ${k} in .env"; return 1; }
}

if grep -q '^APP_KEY=base64:.\{40,\}' .env 2>/dev/null; then
  ok "APP_KEY is set"
else
  note_issue
  if [ "$CHECK_ONLY" = "yes" ]; then
    bad "APP_KEY is empty (the panel cannot boot)"; note_unresolved
  else
    # Never rotate a key over existing data: it kills every session and makes
    # encrypted columns permanently undecryptable.
    HAS_DATA="no"
    if [ "$FORCE_KEY" = "no" ] && grep -q '^APP_KEY=base64:' .env 2>/dev/null; then HAS_DATA="maybe"; fi
    NEWKEY="$(php -r 'echo base64_encode(random_bytes(32));' 2>/dev/null)"
    if [ "${#NEWKEY}" -ne 44 ]; then
      bad "Could not generate APP_KEY (is the php CLI working?)"; note_unresolved
    elif [ "$HAS_DATA" = "maybe" ]; then
      bad "APP_KEY looks malformed but is not empty — refusing to rotate it over existing data."
      bad "  Re-run with --force-key ONLY if this install has no encrypted data yet."; note_unresolved
    else
      rm -f bootstrap/cache/config.php
      if env_set APP_KEY "base64:${NEWKEY}" && grep -q '^APP_KEY=base64:.\{40,\}' .env; then
        fix "Generated and verified a new APP_KEY"; note_fixed
      else
        bad "APP_KEY did not persist to .env"; note_unresolved
      fi
    fi
  fi
fi

APP_URL="$(env_get APP_URL)"
if [ -z "$APP_URL" ] || [ "$APP_URL" = "http://panel.example.com" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && [ -n "$PRIMARY_IP" ] && env_set APP_URL "http://${PRIMARY_IP}"; then
    fix "APP_URL set to http://${PRIMARY_IP}"; note_fixed
  else
    bad "APP_URL is unset or still the example value"; note_unresolved
  fi
else
  ok "APP_URL is ${APP_URL}"
  URL_HOST="${APP_URL#*://}"; URL_HOST="${URL_HOST%%[:/]*}"
  if [ "${APP_URL#https://}" != "$APP_URL" ] && [[ "$URL_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # Only downgrade when there is genuinely no TLS — otherwise nginx would keep
    # redirecting to https while Laravel emits http URLs (redirect loops).
    if [ ! -d /etc/letsencrypt/live ] && ! grep -rq 'listen[^;]*443' /etc/nginx/sites-enabled/ 2>/dev/null; then
      note_issue
      if [ "$CHECK_ONLY" = "no" ] && env_set APP_URL "http://${URL_HOST}"; then
        fix "APP_URL used https with a bare IP and no certificate exists — switched to http"; note_fixed
      else
        bad "APP_URL uses https with a bare IP but no certificate is configured"; note_unresolved
      fi
    else
      warn "APP_URL uses https with a bare IP, but a certificate/443 listener exists — leaving it alone"
    fi
  fi
fi

# SESSION_SECURE_COOKIE must agree with the APP_URL scheme. Pterodactyl sets it
# to true whenever APP_URL is https; if the panel is then served over plain
# HTTP the browser never returns the Secure session cookie, so every request
# starts a new session and login fails with "CSRF token mismatch."
secure_cookie_ok() {
  local url secure
  url="$(env_get APP_URL)"; secure="$(env_get SESSION_SECURE_COOKIE)"
  case "$url" in
    https://*) return 0 ;;                       # https: either setting is fine
    *) case "$secure" in true|"1"|on) return 1 ;; *) return 0 ;; esac ;;
  esac
}
repair_secure_cookie() {
  env_set SESSION_SECURE_COOKIE "false" || return 1
  rm -f bootstrap/cache/config.php
  detail "SESSION_SECURE_COOKIE was true while APP_URL is $(env_get APP_URL)."
  detail "A Secure cookie is never sent over plain HTTP, so the session was lost on"
  detail "every request and login failed with 'CSRF token mismatch.' — now false."
  return 0
}
repair_step "Session cookie security matches the APP_URL scheme" secure_cookie_ok repair_secure_cookie

awk -F= '/^[A-Z_]+=/{if(seen[$1]++) print "         DUPLICATE .env key: "$1}' .env 2>/dev/null
grep -q $'\r' .env 2>/dev/null && warn ".env has CRLF line endings — values will carry a trailing carriage return"

[ "$CHECK_ONLY" = "no" ] && rm -f bootstrap/cache/config.php

# ── 8. Runtime directories ─────────────────────────────────────────────────
head_ "Runtime directories"
RUNTIME_DIRS="storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache"
MISSING_DIRS=""
for d in $RUNTIME_DIRS; do [ -d "$d" ] || MISSING_DIRS="$MISSING_DIRS $d"; done
if [ -n "$MISSING_DIRS" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    mkdir -p $RUNTIME_DIRS
    fix "Created missing runtime directories:$MISSING_DIRS"; note_fixed
  else
    bad "Missing runtime directories:$MISSING_DIRS"; note_unresolved
  fi
else
  ok "Runtime directories present"
fi

df -h "$PANEL_DIR" 2>/dev/null | awk 'NR==2 && int($5)>95 {print "         WARNING: disk is "$5" full"}'
df -i "$PANEL_DIR" 2>/dev/null | awk 'NR==2 && int($5)>95 {print "         WARNING: inodes are "$5" full"}'

MISSING_EXT=""
for e in gd pdo_mysql mbstring bcmath xml curl zip; do
  php -m 2>/dev/null | grep -qix "$e" || MISSING_EXT="$MISSING_EXT $e"
done
if [ -n "$MISSING_EXT" ]; then
  note_issue; note_unresolved
  bad "Missing PHP extensions:$MISSING_EXT (install php${PHP_VER}-{${MISSING_EXT// /,}})"
else
  ok "Required PHP extensions present"
fi

# ── 9. Services ────────────────────────────────────────────────────────────
head_ "Services"
for svc in mariadb redis-server nginx "$FPM_SVC"; do
  [ -n "$svc" ] || continue
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    ok "$svc is running"
  else
    note_issue
    if [ "$CHECK_ONLY" = "no" ] && systemctl enable --now "$svc" >/dev/null 2>&1 && systemctl is-active --quiet "$svc"; then
      fix "Started $svc"; note_fixed
    else
      bad "$svc is not running"; note_unresolved
    fi
  fi
done
if command -v redis-cli >/dev/null 2>&1; then
  redis-cli -h "$(env_get REDIS_HOST || echo 127.0.0.1)" -p "$(env_get REDIS_PORT || echo 6379)" ping 2>/dev/null | grep -q PONG \
    && ok "Redis answered PING" || { note_issue; note_unresolved; bad "Redis did not answer PING (cache/session/queue driver is redis)"; }
fi

# ── 10. Database ───────────────────────────────────────────────────────────
head_ "Database"
if as_user "$FPM_USER" php artisan db:show >/dev/null 2>&1 || as_user "$FPM_USER" php artisan migrate:status >/dev/null 2>&1; then
  ok "Database connection works"
  STATUS_OUT="$(as_user "$FPM_USER" php artisan migrate:status 2>&1)"; STATUS_RC=$?
  NEEDS_MIGRATE="no"
  if [ "$STATUS_RC" -ne 0 ] || printf '%s' "$STATUS_OUT" | grep -q 'Migration table not found'; then
    NEEDS_MIGRATE="yes"; note_issue; bad "Migrations table is missing — the database is not initialised"
  elif printf '%s' "$STATUS_OUT" | grep -qE '(^|[[:space:]])Pending([[:space:]]|$)'; then
    NEEDS_MIGRATE="yes"; note_issue; bad "There are pending migrations"
  else
    ok "Migrations are up to date"
  fi

  if [ "$NEEDS_MIGRATE" = "yes" ] && [ "$CHECK_ONLY" = "no" ]; then
    if as_user "$FPM_USER" php artisan migrate --force; then
      fix "Ran pending migrations (schema only)"; note_fixed
    else
      bad "Migrations failed"; note_unresolved
    fi
    if [ "$ALLOW_SEED" = "yes" ]; then
      warn "Seeding: stock eggs WILL be reset to bundled defaults, overwriting admin customisations."
      as_user "$FPM_USER" php artisan db:seed --force
    else
      warn "Skipped seeding. Pass --seed to import stock eggs (this OVERWRITES egg customisations)."
    fi
  fi
else
  note_issue; note_unresolved
  bad "Cannot connect to the database — check DB_* values in .env"
fi

# ── 11. Dependencies & assets ──────────────────────────────────────────────
head_ "Dependencies & assets"
if [ -d vendor ]; then
  ok "PHP dependencies installed (vendor/)"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && command -v composer >/dev/null 2>&1; then
    detail "Installing PHP dependencies (composer)..."
    if COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --quiet; then
      fix "composer install complete"; note_fixed
    else
      bad "composer install failed"; note_unresolved
    fi
  else
    bad "vendor/ is missing — run: composer install --no-dev --optimize-autoloader"; note_unresolved
  fi
fi

assets_ok() { [ -f public/assets/manifest.json ] && ls public/assets/*.js >/dev/null 2>&1; }
if assets_ok; then
  ok "Frontend assets are built"
else
  note_issue
  if [ "$CHECK_ONLY" = "no" ] && command -v yarn >/dev/null 2>&1; then
    AVAIL_MB="$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null)"
    if [ "${AVAIL_MB:-9999}" -lt 1500 ]; then
      bad "Only ${AVAIL_MB}MB RAM available; webpack will likely run out of memory. Add swap, then re-run."
      note_unresolved
    else
      # build:production deletes existing bundles first, so keep a copy: a failed
      # build would otherwise leave a white page where a working UI stood.
      ASSET_BAK="$(mktemp -d)"
      cp -a public/assets "$ASSET_BAK/" 2>/dev/null
      detail "Building frontend assets (this takes a minute)..."
      if yarn install --frozen-lockfile --silent && yarn build:production >/dev/null; then
        rm -rf "$ASSET_BAK"; fix "Assets built"; note_fixed
      else
        rm -rf public/assets && cp -a "$ASSET_BAK/assets" public/assets && rm -rf "$ASSET_BAK"
        bad "Asset build failed — restored the previous assets"; note_unresolved
      fi
    fi
  else
    bad "public/assets is not built — run: yarn install && yarn build:production"; note_unresolved
  fi
fi

# ── 12. nginx ──────────────────────────────────────────────────────────────
head_ "Web server configuration"

site_directive() { awk -v d="$2" '$1==d{v=$2; sub(/;.*/,"",v); print v; exit}' "$1" 2>/dev/null; }
find_site() {
  local s
  for s in /etc/nginx/sites-available/touchdown.conf /etc/nginx/sites-available/pterodactyl.conf; do
    [ -f "$s" ] && { printf '%s\n' "$s"; return 0; }
  done
  return 1
}

write_site_config() {
  cat > /etc/nginx/sites-available/touchdown.conf <<EOF
server {
    listen 80 default_server;
    server_name ${PRIMARY_IP:-_} _;

    root ${WANT_ROOT};
    index index.php;

    access_log /var/log/nginx/touchdown.app-access.log;
    error_log  /var/log/nginx/touchdown.app-error.log warn;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${FPM_TARGET};
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
  ln -sf /etc/nginx/sites-available/touchdown.conf /etc/nginx/sites-enabled/touchdown.conf
  detail "Created nginx site config (root=${WANT_ROOT}, fastcgi_pass=${FPM_TARGET})"
}

site_exists_ok()  { find_site >/dev/null 2>&1; }
repair_site_exists() { write_site_config; return 0; }
repair_step "Panel nginx site config exists" site_exists_ok repair_site_exists

site_enabled_ok() {
  local s l; s="$(find_site)" || return 1
  l="/etc/nginx/sites-enabled/$(basename "$s")"
  [ -e "$l" ]
}
repair_site_enabled() {
  local s; s="$(find_site)" || return 1
  ln -sf "$s" "/etc/nginx/sites-enabled/$(basename "$s")"
  detail "Enabled $(basename "$s")"
  return 0
}
repair_step "Panel nginx site is enabled" site_enabled_ok repair_site_enabled

nginx_root_ok() {
  local s; s="$(find_site)" || return 1
  [ "$(site_directive "$s" root)" = "$WANT_ROOT" ]
}
repair_nginx_root() {
  local s cur
  s="$(find_site)" || { write_site_config; return 0; }
  s="$(readlink -f "$s")"   # never sed -i a symlink; it would detach sites-enabled
  cur="$(site_directive "$s" root)"
  cp -a "$s" "${s}.bak.$(date +%s)"
  if [ -n "$cur" ]; then
    sed -i -E "s|^([[:space:]]*)root[[:space:]]+[^;]+;|\1root ${WANT_ROOT};|" "$s"
  else
    sed -i -E "0,/^[[:space:]]*listen[[:space:]]/{s|^([[:space:]]*)listen([^;]*);|\1listen\2;\n\1root ${WANT_ROOT};|}" "$s"
  fi
  detail "nginx root was '${cur:-<unset>}' -> '${WANT_ROOT}' (backup written alongside)"
  return 0
}
repair_step "nginx root matches the panel path" nginx_root_ok repair_nginx_root

fastcgi_pass_ok() {
  local s cur; s="$(find_site)" || return 1
  cur="$(sed -nE 's/^[[:space:]]*fastcgi_pass[[:space:]]+([^;]+);.*/\1/p' "$s" | head -1)"
  [ -n "$cur" ] || return 1
  case "$cur" in unix:*) [ -S "${cur#unix:}" ] || return 1 ;; esac
  [ -z "$FPM_TARGET" ] || [ "$cur" = "$FPM_TARGET" ]
}
repair_fastcgi_pass() {
  local s cur
  [ -n "$FPM_TARGET" ] || { bad "No php-fpm listener discovered; cannot repair fastcgi_pass"; return 1; }
  s="$(readlink -f "$(find_site)")"
  cur="$(sed -nE 's/^[[:space:]]*fastcgi_pass[[:space:]]+([^;]+);.*/\1/p' "$s" | head -1)"
  cp -a "$s" "${s}.bak.$(date +%s)"
  sed -i -E "s|^([[:space:]]*)fastcgi_pass[[:space:]]+[^;]+;|\1fastcgi_pass ${FPM_TARGET};|" "$s"
  detail "fastcgi_pass was '${cur:-<unset>}' -> '${FPM_TARGET}' (discovered from ${FPM_POOL})"
  return 0
}
repair_step "nginx fastcgi_pass points at the live php-fpm listener" fastcgi_pass_ok repair_fastcgi_pass

# Stale/shadowing server blocks. Browsing by IP against a config whose
# server_name is a domain falls through to whatever owns default_server —
# that is what produces "Welcome to nginx!".
stale_sites_ok() {
  local l t r keep
  keep="$(readlink -f "$(find_site 2>/dev/null)" 2>/dev/null)"
  for l in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
    [ -e "$l" ] || continue
    t="$(readlink -f "$l")"; [ "$t" = "$keep" ] && continue
    [ "$(basename "$l")" = "default" ] && return 1
    r="$(site_directive "$t" root)"
    [ -n "$r" ] && [ ! -d "$r" ] && return 1
    case "$r" in */public) [ "$r" != "$WANT_ROOT" ] && return 1 ;; esac
  done
  return 0
}
repair_stale_sites() {
  local l t r keep bak="/root/nginx-disabled-by-touchdown"
  install -d "$bak"
  keep="$(readlink -f "$(find_site)")"
  for l in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
    [ -e "$l" ] || continue
    t="$(readlink -f "$l")"; [ "$t" = "$keep" ] && continue
    r="$(site_directive "$t" root)"
    if [ "$(basename "$l")" = "default" ]; then
      mv "$l" "${bak}/default.$(date +%s)"
      detail "Disabled nginx's default site (the 'Welcome to nginx!' page); backup in ${bak}"
      continue
    fi
    if { [ -n "$r" ] && [ ! -d "$r" ]; } || { case "$r" in */public) [ "$r" != "$WANT_ROOT" ] ;; *) false ;; esac; }; then
      mv "$l" "${bak}/$(basename "$l").$(date +%s)"
      detail "Disabled ${l} — its root '${r}' points at a different/missing panel; backup in ${bak}"
    fi
  done
  return 0
}
repair_step "No stale or shadowing nginx server blocks" stale_sites_ok repair_stale_sites

server_name_ok() {
  local s; s="$(find_site)" || return 1
  grep -qE '^[[:space:]]*listen[[:space:]]+(\[::\]:)?80[[:space:]]+default_server;' "$s" || return 1
  [ -z "$PRIMARY_IP" ] || grep -qE "^[[:space:]]*server_name[[:space:]].*(${PRIMARY_IP//./\\.}|_)" "$s"
}
repair_server_name() {
  local s cur
  s="$(readlink -f "$(find_site)")"
  # Two default_server blocks on one listen is a hard nginx error, so refuse
  # to add a second rather than take the whole web server down.
  if grep -rlE '^[[:space:]]*listen[^;]*default_server' /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null \
     | grep -qv "$(basename "$s")"; then
    bad "Another enabled block already claims default_server; not adding a second"
    return 1
  fi
  cur="$(site_directive "$s" server_name)"
  cp -a "$s" "${s}.bak.$(date +%s)"
  sed -i -E 's|^([[:space:]]*)listen[[:space:]]+80;|\1listen 80 default_server;|' "$s"
  sed -i -E "s|^([[:space:]]*)server_name[[:space:]]+[^;]+;|\1server_name ${PRIMARY_IP:-_} _;|" "$s"
  detail "server_name was '${cur:-<unset>}' -> '${PRIMARY_IP:-_} _'; listen 80 is now default_server"
  detail "(browsing by IP matched no server_name, so nginx fell through to the default site)"
  return 0
}
repair_step "Panel block deterministically answers requests by IP" server_name_ok repair_server_name

echo "         Config files and their roots (nginx -T):"
nginx -T 2>/dev/null | awk '
  /^# configuration file /{f=$4; sub(/:$/,"",f); next}
  $1=="root"{v=$2; sub(/;.*/,"",v); printf "         %-52s root=%s\n", f, v}' | sort -u

# nginx -t with rollback: never leave an invalid config enabled, or the next
# unrelated reload (certbot, logrotate) takes down every site on the box.
if [ "$CHECK_ONLY" = "no" ]; then
  SITE_NOW="$(readlink -f "$(find_site 2>/dev/null)" 2>/dev/null)"
  if nginx -t >/dev/null 2>&1; then
    if systemctl reload-or-restart nginx >/dev/null 2>&1; then
      ok "nginx config valid and reloaded"
    else
      note_issue; note_unresolved; bad "nginx config is valid but reload failed:"
      systemctl status nginx --no-pager -n 10 2>/dev/null | sed 's/^/         /'
    fi
  else
    note_issue
    bad "nginx config test FAILED — rolling back this script's changes:"
    nginx -t 2>&1 | sed 's/^/         /'
    BAK="$(ls -1t "${SITE_NOW}".bak.* 2>/dev/null | head -1)"
    if [ -n "$BAK" ] && cp -a "$BAK" "$SITE_NOW" && nginx -t >/dev/null 2>&1; then
      systemctl reload-or-restart nginx >/dev/null 2>&1
      warn "Restored ${BAK} — nginx is valid again, but the panel site was NOT repaired"
    else
      bad "Rollback did not restore a valid config; nginx was NOT reloaded"
    fi
    note_unresolved
  fi
fi

# ── 13. Background workers ─────────────────────────────────────────────────
head_ "Background workers"
PTEROQ_UNIT="/etc/systemd/system/pteroq.service"

# Reports which specific condition failed, so a failure is actionable rather
# than just "verification failed".
pteroq_why() {
  [ -f "$PTEROQ_UNIT" ] || { echo "unit file ${PTEROQ_UNIT} does not exist"; return; }
  grep -qE "^ExecStart=.*${PANEL_DIR}/artisan" "$PTEROQ_UNIT" \
    || { echo "ExecStart in the unit file does not reference ${PANEL_DIR}/artisan: $(grep -E '^ExecStart=' "$PTEROQ_UNIT" || echo '<no ExecStart line>')"; return; }
  systemctl is-active --quiet pteroq \
    || { echo "service is not active (state: $(systemctl is-active pteroq 2>&1))"; return; }
  echo "unknown"
}

pteroq_ok() {
  # Match against the unit file we control, not systemd's rendered ExecStart
  # property, whose format varies between systemd versions.
  [ -f "$PTEROQ_UNIT" ] || return 1
  grep -qE "^ExecStart=.*${PANEL_DIR}/artisan" "$PTEROQ_UNIT" || return 1
  systemctl is-active --quiet pteroq || return 1
  return 0
}
repair_pteroq() {
  cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Touch Down Hosting Panel Queue Worker
After=redis-server.service mariadb.service

[Service]
User=${FPM_USER}
Group=${FPM_USER}
Restart=always
ExecStart=${PHP_BIN} ${PANEL_DIR}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable pteroq >/dev/null 2>&1
  systemctl restart pteroq >/dev/null 2>&1
  detail "pteroq.service now runs ${PHP_BIN} ${PANEL_DIR}/artisan as ${FPM_USER}"

  # Give it a moment to fail, then explain WHY rather than just reporting a
  # failed verification. A queue worker that cannot reach redis/the database
  # crash-loops, and the reason only appears in the journal.
  sleep 2
  if ! systemctl is-active --quiet pteroq; then
    bad "pteroq did not stay running. Reason:"
    systemctl status pteroq --no-pager -n 5 2>/dev/null | sed 's/^/         /'
    journalctl -u pteroq -n 15 --no-pager 2>/dev/null | sed 's/^/         /'
    detail "Common causes: redis/database unreachable, or .env not yet configured."
    detail "The panel web interface works without the queue worker — this affects"
    detail "scheduled tasks, server installs, backups and outgoing email only."
  fi
  return 0
}
if ! repair_step "Queue worker (pteroq) runs the correct panel" pteroq_ok repair_pteroq; then
  detail "Reason: $(pteroq_why)"
  detail "The panel web interface does NOT depend on this worker — it affects"
  detail "scheduled tasks, server installs, backups and outgoing email only."
fi

cron_ok() { crontab -u "$FPM_USER" -l 2>/dev/null | grep -qF "${PANEL_DIR}/artisan schedule:run"; }
repair_cron() {
  local cur rc
  cur="$(crontab -u "$FPM_USER" -l 2>/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ] && [ -n "$cur" ]; then
    bad "Cannot read ${FPM_USER}'s crontab — refusing to modify it"; return 1
  fi
  # Never sort a crontab: environment assignments are positional.
  { printf '%s\n' "$cur" | grep -v 'artisan schedule:run'
    echo "* * * * * ${PHP_BIN} ${PANEL_DIR}/artisan schedule:run >> /dev/null 2>&1"
  } | grep -v '^$' | crontab -u "$FPM_USER" -
  detail "Scheduler cron entry set to ${PANEL_DIR}/artisan (stale entries removed, order preserved)"
  return 0
}
repair_step "Scheduler cron entry points at ${PANEL_DIR}" cron_ok repair_cron

# ── 14. Ownership and modes — LAST, because earlier steps ran as root ──────
head_ "Ownership & permissions"
perms_ok() {
  local d
  for d in storage storage/framework/cache/data storage/framework/sessions \
           storage/framework/views storage/logs bootstrap/cache; do
    [ -d "$d" ] || return 1
    as_user "$FPM_USER" test -w "$d" 2>/dev/null || return 1
  done
  [ -f .env ] || return 1
  [ "$(stat -c '%a' .env)" = "600" ] || return 1
  [ "$(stat -c '%U' .env)" = "$FPM_USER" ] || return 1
  fpm_can_read_index
}
repair_perms() {
  mkdir -p $RUNTIME_DIRS
  chown -R "${FPM_USER}:${FPM_USER}" "$PANEL_DIR"
  # dirs 755 / files 644 — NOT chmod -R 755, which would make laravel.log
  # (stack traces, credentials) world-readable.
  find "$PANEL_DIR" -type d -exec chmod 755 {} + 2>/dev/null
  find "$PANEL_DIR" -type f -exec chmod 644 {} + 2>/dev/null
  chmod 755 "$PANEL_DIR/artisan" 2>/dev/null
  find "$PANEL_DIR/installer" -name '*.sh' -exec chmod 755 {} + 2>/dev/null
  [ -f "$PANEL_DIR/.env" ] && { chmod 600 "$PANEL_DIR/.env"; chown "${FPM_USER}:${FPM_USER}" "$PANEL_DIR/.env"; }
  detail "Ownership -> ${FPM_USER}:${FPM_USER}; dirs 755, files 644, .env 600"
  return 0
}
repair_step "Runtime directories are writable by ${FPM_USER}" perms_ok repair_perms

# ── 14b. Repository access (needed for updates, not for serving) ──────────
head_ "Repository access"
GIT_REMOTE="$(git -C "$PANEL_DIR" remote get-url origin 2>/dev/null)"
if [ -z "$GIT_REMOTE" ]; then
  warn "No git remote configured — installer/update-touchdown-panel.sh cannot pull updates"
elif GIT_TERMINAL_PROMPT=0 git -C "$PANEL_DIR" ls-remote origin HEAD >/dev/null 2>&1; then
  ok "Repository reachable: ${GIT_REMOTE} (branch: $(git -C "$PANEL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null))"
else
  warn "Cannot reach ${GIT_REMOTE} — updates will fail until credentials are available."
  detail "For a private repository, store a read-only token for root:"
  detail "  printf 'https://USER:TOKEN@$(printf '%s' "${GIT_REMOTE#*://}" | cut -d/ -f1)\\n' > /root/.git-credentials"
  detail "  chmod 600 /root/.git-credentials && git config --global credential.helper store"
  detail "Use a Gitea access token (read:repository), never an account password."
fi
if [ -f /root/.git-credentials ] && [ "$(stat -c '%a' /root/.git-credentials 2>/dev/null)" != "600" ]; then
  note_issue
  if [ "$CHECK_ONLY" = "no" ]; then
    chmod 600 /root/.git-credentials; fix "Tightened /root/.git-credentials to mode 600"; note_fixed
  else
    bad "/root/.git-credentials is not mode 600"; note_unresolved
  fi
fi

# ── 15. End-to-end verification ────────────────────────────────────────────
head_ "End-to-end verification"
[ "$CHECK_ONLY" = "no" ] && as_user "$FPM_USER" php artisan config:clear >/dev/null 2>&1

SITE_FILE="$(find_site 2>/dev/null)"
SN="$(site_directive "$SITE_FILE" server_name 2>/dev/null)"
{ [ -z "$SN" ] || [ "$SN" = "_" ]; } && SN="${PRIMARY_IP:-localhost}"

RESP="$(curl -sS -m 15 -H "Host: ${SN}" -o - -w '\n%{http_code}' http://127.0.0.1/ 2>&1)"
CODE="${RESP##*$'\n'}"; BODY="${RESP%$'\n'*}"

case "$CODE" in
  200|302)
    ok "Panel responded HTTP ${CODE} (Host: ${SN}) — it is serving"
    [ -n "$PRIMARY_IP" ] && curl -sS -m 10 -o /dev/null \
      -w "         via ${PRIMARY_IP}: HTTP %{http_code}\n" "http://${PRIMARY_IP}/" 2>/dev/null
    ;;
  *)
    note_issue; note_unresolved
    bad "Panel is NOT serving correctly (HTTP ${CODE}, Host: ${SN})"
    case "$BODY" in
      *"File not found."*)
        bad "  php-fpm cannot open ${WANT_ROOT}/index.php. Causes, in order:"
        bad "    1) ${FPM_USER} cannot traverse a parent directory"
        bad "    2) nginx root does not match the panel path"
        bad "    3) ProtectHome= on ${FPM_SVC} masks /home"
        bad "    4) open_basedir excludes ${PANEL_DIR}"
        report_access_evidence ;;
      *"Welcome to nginx"*)
        bad "  Another server block is winning the Host match — see the nginx -T audit above." ;;
      *"Access denied."*)
        bad "  security.limit_extensions in ${FPM_POOL} is rejecting .php" ;;
      *)
        case "$CODE" in
          502|504) bad "  Bad gateway — php-fpm down or wrong socket (target: ${FPM_TARGET})" ;;
          000)     bad "  Nothing answered on port 80: $(ss -ltn 2>/dev/null | grep ':80 ' || echo 'no listener')" ;;
          500)     bad "  nginx and php-fpm are fine; the fault is application-level (.env, DB, storage writability)" ;;
        esac
        bad "  Body: $(printf '%s' "$BODY" | head -c 200)" ;;
    esac
    echo; bad "── nginx error log ──"
    tail -n 20 /var/log/nginx/touchdown.app-error.log /var/log/nginx/error.log 2>/dev/null | sed 's/^/         /'
    echo; bad "── php-fpm error log ──"
    tail -n 20 /var/log/php*-fpm.log 2>/dev/null | sed 's/^/         /'
    echo; bad "── laravel log ──"
    tail -n 20 "${PANEL_DIR}/storage/logs/laravel.log" 2>/dev/null | sed 's/^/         /'
    ;;
esac

# ── Summary ────────────────────────────────────────────────────────────────
echo
echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"
if [ "$CHECK_ONLY" = "yes" ]; then
  echo -e "  ${WHITE}Health check complete — ${ISSUES} issue(s) found.${RESET}"
  [ "$ISSUES" -gt 0 ] && echo -e "  Re-run without --check to repair them."
else
  echo -e "  ${WHITE}Repair complete — ${ISSUES} issue(s) found, ${FIXED} fixed.${RESET}"
fi
echo -e "  Panel path:    ${WHITE}${PANEL_DIR}${RESET}"
echo -e "  Panel address: ${WHITE}$(env_get APP_URL 2>/dev/null || echo "http://${PRIMARY_IP}")${RESET}"
case "$PANEL_DIR" in
  /home/*) echo -e "  ${YELLOW}Note:${RESET} the panel lives under /home, which needs traverse grants on the"
           echo -e "        home directory. /var/www/touchdown avoids that entirely." ;;
esac
echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"

if [ "$UNRESOLVED" -gt 0 ]; then
  echo -e "  ${RED}${UNRESOLVED} issue(s) could NOT be repaired — see the [ FAIL ] lines above.${RESET}"
  exit 1
fi
exit 0
