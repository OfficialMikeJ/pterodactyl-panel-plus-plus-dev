#!/bin/bash
set -Eeuo pipefail

# Loud failures: under plain set -e a failing command can abort the script
# with no output at all (the cron pipeline did exactly that). This trap makes
# every fatal error name the line and command that caused it.
trap 'rc=$?; echo -e "\033[0;31m[ERROR ]\033[0m Installer failed at line ${LINENO}: ${BASH_COMMAND} (exit ${rc})" >&2' ERR

#############################################################################
#                                                                           #
#  Touch Down Hosting Panel Installer                                       #
#                                                                           #
#  Installs the Touch Down Hosting panel (a Pterodactyl 1.14.1 fork) from  #
#  its GitHub repository onto a fresh server.                              #
#                                                                           #
#  Modeled on the pterodactyl-installer / pyrodactyl-installer projects:   #
#  https://github.com/Muspelheim-Hosting/pyrodactyl-installer              #
#                                                                           #
#  Supported: Ubuntu 22.04 / 24.04, Debian 11 / 12 / 13                     #
#  Run as root:  bash install-touchdown-panel.sh                            #
#                                                                           #
#  Unlike upstream installers that download a pre-built release tarball,    #
#  this fork's repository is source-only — so this script also installs    #
#  Node.js 22 + Yarn and builds the frontend assets on the server.         #
#                                                                           #
#  NOTE: This installs the PANEL only. Wings is unmodified in this fork —  #
#  use the official installer for Wings: https://pterodactyl-installer.se  #
#                                                                           #
#############################################################################

# ── Configuration (override via environment or answer the prompts) ────────
GIT_REPO="${GIT_REPO:-https://github.com/OfficialMikeJ/pterodactyl-panel-plus-plus-dev.git}"
GIT_USERNAME="${GIT_USERNAME:-}"              # only needed for a PRIVATE repository
GIT_TOKEN="${GIT_TOKEN:-}"                    # git ACCESS TOKEN (repo read) — never an account password
CHANNEL="${CHANNEL:-}"                        # public (main branch, Alpha) | dev (dev branch, internal build)
GIT_BRANCH="${GIT_BRANCH:-}"                  # derived from CHANNEL unless set explicitly
AUTO_UPDATE="${AUTO_UPDATE:-}"                # yes/no — default: no (opt-in; both builds update manually)
DEV_FEATURES_USERS="${DEV_FEATURES_USERS:-}"  # comma-separated emails (dev channel only)
PANEL_DIR="${PANEL_DIR:-/var/www/touchdown}"
FQDN="${FQDN:-}"                              # e.g. panel.touchdownhosting.com
PANEL_PORT="${PANEL_PORT:-80}"                # nginx port for the panel; prompts for a free one if taken (e.g. OMV web UI on 80)
TIMEZONE="${TIMEZONE:-America/Chicago}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_FIRST="${ADMIN_FIRST:-Touch}"
ADMIN_LAST="${ADMIN_LAST:-Down}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"          # leave empty to be prompted
CONFIGURE_SSL="${CONFIGURE_SSL:-yes}"         # yes = Let's Encrypt via certbot
DB_NAME="${DB_NAME:-panel}"
DB_USER="${DB_USER:-touchdown}"
DB_PASSWORD="${DB_PASSWORD:-$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)}"
DB_PORT="${DB_PORT:-3306}"                    # auto-bumps to the next free port if taken (e.g. by a Docker container)
PHP_VERSION="8.3"

# ── UI helpers ─────────────────────────────────────────────────────────────
ORANGE='\033[38;5;208m'
WHITE='\033[1;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

log()     { echo -e "${ORANGE}[Touch Down]${RESET} $1"; }
success() { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR ]${RESET} $1" >&2; }
banner() {
  echo -e "${ORANGE}"
  cat <<'EOF'
  _____                _        ____
 |_   _|__  _   _  ___| |__    |  _ \  _____      ___ __
   | |/ _ \| | | |/ __| '_ \   | | | |/ _ \ \ /\ / / '_ \
   | | (_) | |_| | (__| | | |  | |_| | (_) \ V  V /| | | |
   |_|\___/ \__,_|\___|_| |_|  |____/ \___/ \_/\_/ |_| |_|
                    H  O  S  T  I  N  G
EOF
  echo -e "${WHITE}          Panel Installer — Pterodactyl 1.14.1 fork${RESET}\n"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root (try: sudo bash $0)"
    exit 1
  fi
}

detect_os() {
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="$ID"
  OS_VERSION="${VERSION_ID%%.*}"

  case "$OS_ID" in
    ubuntu) [[ "$VERSION_ID" =~ ^(22.04|24.04)$ ]] || { error "Unsupported Ubuntu version: $VERSION_ID"; exit 1; } ;;
    debian) [[ "$OS_VERSION" =~ ^(11|12|13)$ ]] || { error "Unsupported Debian version: $VERSION_ID"; exit 1; } ;;
    *) error "Unsupported OS: $OS_ID (Ubuntu 22.04/24.04 or Debian 11/12/13 required)"; exit 1 ;;
  esac
  success "Detected $PRETTY_NAME"
}

# Password policy for the master admin account: 12-64 characters with at
# least one lowercase letter, one uppercase letter, one number and one
# special character. Matches the panel's reset-master-password script.
validate_password() {
  local p="$1" len=${#1}
  if [ "$len" -lt 12 ] || [ "$len" -gt 64 ]; then
    echo "Password must be between 12 and 64 characters."; return 1
  fi
  [[ "$p" =~ [a-z] ]] || { echo "Password must contain at least one lowercase letter."; return 1; }
  [[ "$p" =~ [A-Z] ]] || { echo "Password must contain at least one uppercase letter."; return 1; }
  [[ "$p" =~ [0-9] ]] || { echo "Password must contain at least one number."; return 1; }
  [[ "$p" =~ [^a-zA-Z0-9] ]] || { echo "Password must contain at least one special character (e.g. !@#\$%)."; return 1; }
  return 0
}

prompt_admin_password() {
  local problem confirm_pw
  echo "Admin password requirements: 12-64 chars, with lowercase, uppercase, a number and a special character."
  while :; do
    read -rsp "Admin account password: " ADMIN_PASSWORD; echo
    if ! problem="$(validate_password "$ADMIN_PASSWORD")"; then
      error "$problem"; continue
    fi
    read -rsp "Confirm admin password: " confirm_pw; echo
    if [ "$ADMIN_PASSWORD" != "$confirm_pw" ]; then
      error "Passwords do not match, please try again."; continue
    fi
    break
  done
}

# ── Private repository access ──────────────────────────────────────────────
# Credentials are stored for root only, OUTSIDE the panel directory, so the
# repository itself never contains them, `git remote -v` stays clean, and the
# update script keeps working unattended.
urlencode() {
  local s="$1" i c out=""
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+="$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

repo_reachable() {
  GIT_TERMINAL_PROMPT=0 git ls-remote "$GIT_REPO" HEAD >/dev/null 2>&1
}

setup_git_credentials() {
  [ -n "$GIT_TOKEN" ] || return 0
  local proto host
  proto="${GIT_REPO%%://*}"
  host="${GIT_REPO#*://}"; host="${host%%/*}"; host="${host##*@}"
  install -m 600 /dev/null /root/.git-credentials
  printf '%s://%s:%s@%s\n' "$proto" "$(urlencode "$GIT_USERNAME")" "$(urlencode "$GIT_TOKEN")" "$host" \
    > /root/.git-credentials
  chmod 600 /root/.git-credentials
  git config --global credential.helper store
  success "Repository credentials stored in /root/.git-credentials (mode 600, root only)"
}

prompt_repo_credentials() {
  [ -n "$GIT_REPO" ] || return 0
  repo_reachable && return 0

  if [ -z "$GIT_TOKEN" ]; then
    echo
    log "That repository is not readable anonymously — it looks private."
    echo "  On GitHub: Settings -> Developer settings -> Personal access tokens"
    echo "  Scope: repository read access is enough for a panel install"
    echo "  Use an ACCESS TOKEN, not your account password — it is stored on this"
    echo "  server and reused unattended by the update script."
    echo
    [ -z "$GIT_USERNAME" ] && read -rp "Git username: " GIT_USERNAME
    read -rsp "Git access token: " GIT_TOKEN; echo
  fi

  setup_git_credentials
  if ! repo_reachable; then
    error "Still cannot read ${GIT_REPO} with those credentials."
    error "Check the username, the token, and that the token has read:repository scope."
    exit 1
  fi
  success "Repository access confirmed"
}

prompt_config() {
  read -rp "Git repository URL of your panel [${GIT_REPO}]: " repo_answer
  [ -n "$repo_answer" ] && GIT_REPO="$repo_answer"
  prompt_repo_credentials

  if [ -z "$CHANNEL" ]; then
    echo "Which build channel is this server?"
    echo "  1) public — customer-facing Alpha build (main branch)"
    echo "  2) dev    — internal dev build (dev branch)"
    read -rp "Channel [1]: " channel_choice
    case "${channel_choice:-1}" in
      2) CHANNEL="dev" ;;
      *) CHANNEL="public" ;;
    esac
  fi

  if [ "$CHANNEL" != "public" ] && [ "$CHANNEL" != "dev" ]; then
    error "CHANNEL must be 'public' or 'dev'."
    exit 1
  fi

  [ -z "$GIT_BRANCH" ] && { [ "$CHANNEL" = "dev" ] && GIT_BRANCH="dev" || GIT_BRANCH="main"; }
  # Scheduled auto-update is opt-in only (AUTO_UPDATE=yes); both builds update
  # manually by default via installer/update-touchdown-panel.sh.
  [ -z "$AUTO_UPDATE" ] && AUTO_UPDATE="no"

  [ -z "$FQDN" ] && read -rp "Panel domain / FQDN (e.g. panel.example.com): " FQDN

  # Let's Encrypt cannot issue certificates for a bare IP address, so an IP
  # install is always plain HTTP. Getting this wrong makes Pterodactyl mark the
  # session cookie Secure, which is never sent over HTTP — login then fails
  # with "CSRF token mismatch." Must run AFTER the FQDN is known.
  if [[ "$FQDN" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    if [ "$CONFIGURE_SSL" = "yes" ]; then
      log "FQDN is a bare IP address — disabling Let's Encrypt (certificates require a domain)."
    fi
    CONFIGURE_SSL="no"
  fi
  [ "$CONFIGURE_SSL" = "yes" ] && APP_SCHEME="https" || APP_SCHEME="http"

  # ── Panel web port ──
  # Another web UI may already own the port — OpenMediaVault's admin UI, for
  # example, is served by nginx on 80. Only the panel's own vhost may hold
  # the chosen port; anything else triggers a prompt for a free one.
  port_taken() { [ -n "$(ss -ltnH "sport = :$1" 2>/dev/null)" ]; }
  panel_owns_port() {
    [ -f /etc/nginx/sites-enabled/touchdown.conf ] \
      && grep -Eq "^[[:space:]]*listen[[:space:]]+$1;" /etc/nginx/sites-enabled/touchdown.conf
  }
  # Re-runs: keep the port an existing panel vhost already uses.
  if [ "$PANEL_PORT" = "80" ] && [ -f /etc/nginx/sites-available/touchdown.conf ]; then
    existing_port="$(sed -n 's/^[[:space:]]*listen[[:space:]]\{1,\}\([0-9]\{1,\}\);.*/\1/p' /etc/nginx/sites-available/touchdown.conf | head -n1)"
    [ -n "$existing_port" ] && PANEL_PORT="$existing_port"
  fi
  if port_taken "$PANEL_PORT" && ! panel_owns_port "$PANEL_PORT"; then
    suggested=8081
    while port_taken "$suggested"; do suggested=$((suggested + 1)); done
    log "Port ${PANEL_PORT} is already in use by another service (e.g. the OMV web UI)."
    read -rp "Port for the panel's web server [${suggested}]: " panel_port_answer
    PANEL_PORT="${panel_port_answer:-$suggested}"
  fi

  # Let's Encrypt needs ports 80/443; a custom-port install sits behind a
  # reverse proxy that terminates TLS itself.
  if [ "$PANEL_PORT" != "80" ] && [ "$CONFIGURE_SSL" = "yes" ]; then
    log "Custom panel port ${PANEL_PORT}: skipping Let's Encrypt — terminate TLS at your reverse proxy instead."
    CONFIGURE_SSL="no"
    APP_SCHEME="http"
  fi

  # The URL users (and the session cookie) see — default ports stay implicit.
  APP_URL="${APP_SCHEME}://${FQDN}"
  if [ "$APP_SCHEME" = "http" ] && [ "$PANEL_PORT" != "80" ]; then
    APP_URL="${APP_URL}:${PANEL_PORT}"
  fi

  [ -z "$ADMIN_EMAIL" ] && read -rp "Admin account email: " ADMIN_EMAIL
  if [ -z "$ADMIN_PASSWORD" ]; then
    prompt_admin_password
  else
    # Password supplied via environment — still has to meet the policy.
    if ! problem="$(validate_password "$ADMIN_PASSWORD")"; then
      error "ADMIN_PASSWORD does not meet the password policy: $problem"
      exit 1
    fi
  fi

  if [ "$CHANNEL" = "dev" ] && [ -z "$DEV_FEATURES_USERS" ]; then
    read -rp "Emails allowed to see dev features [${ADMIN_EMAIL}]: " DEV_FEATURES_USERS
    DEV_FEATURES_USERS="${DEV_FEATURES_USERS:-$ADMIN_EMAIL}"
  fi

  if [ -z "$GIT_REPO" ] || [ -z "$FQDN" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    error "Repository URL, FQDN, admin email and admin password are all required."
    exit 1
  fi

  echo
  log "Installing from:  $GIT_REPO ($GIT_BRANCH)"
  log "Build channel:    $CHANNEL (auto-update: $AUTO_UPDATE)"
  log "Install path:     $PANEL_DIR"
  log "Panel URL:        ${APP_URL}"
  log "Database:         $DB_NAME (user: $DB_USER)"
  log "Let's Encrypt:    $CONFIGURE_SSL"
  [ "$CHANNEL" = "dev" ] && log "Dev feature users: $DEV_FEATURES_USERS"
  echo
  read -rp "Continue with these settings? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy] ]] || exit 0
}

# Composer, artisan, systemd and cron must all use the exact PHP this
# installer provisioned. The bare `php` command can resolve to a different
# version on hosts that already had PHP installed for other projects
# (e.g. Debian 13 defaults to PHP 8.4, which this panel does not support) —
# composer then rejects the lock file and artisan runs under the wrong PHP.
resolve_php_bin() {
  PHP_BIN=""
  for cand in "/usr/bin/php${PHP_VERSION}" "$(command -v "php${PHP_VERSION}" 2>/dev/null)" "$(command -v php 2>/dev/null)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { PHP_BIN="$cand"; break; }
  done
  [ -n "$PHP_BIN" ] || { error "No usable PHP binary found."; exit 1; }
}

# A port is only a problem if something OTHER than the host's own mariadbd
# holds it — mariadbd holding it just means a previous run of this installer.
db_port_busy_by_other() {
  local line
  line="$(ss -ltnpH "sport = :$1" 2>/dev/null || true)"
  [ -n "$line" ] && ! printf '%s' "$line" | grep -q 'mariadbd'
}

# ── Dependencies ───────────────────────────────────────────────────────────
install_dependencies() {
  log "Installing system dependencies..."
  export DEBIAN_FRONTEND=noninteractive

  # If another service (commonly a Docker container publishing 3306) already
  # holds the MariaDB port, run the panel's MariaDB on the next free port.
  # The override must exist BEFORE apt configures mariadb-server, so the
  # service binds the right port on its very first start.
  while db_port_busy_by_other "$DB_PORT"; do
    DB_PORT=$((DB_PORT + 1))
  done
  if [ "$DB_PORT" != "3306" ]; then
    log "Port 3306 is in use by another service — the panel's MariaDB will use port ${DB_PORT}"
    mkdir -p /etc/mysql/mariadb.conf.d
    printf '[mysqld]\nport = %s\n' "$DB_PORT" > /etc/mysql/mariadb.conf.d/99-touchdown-port.cnf
  fi

  # Finish anything a previously interrupted run left half-configured (e.g.
  # mariadb-server after a port clash) — with the port override in place,
  # its deferred service start can now succeed.
  dpkg --configure -a || true

  apt-get update -qq
  apt-get install -y -qq curl ca-certificates gnupg apt-transport-https \
    lsb-release git tar unzip cron

  # PHP repository (Ondrej PPA on Ubuntu, Sury on Debian)
  if [ "$OS_ID" = "ubuntu" ]; then
    # software-properties-common provides add-apt-repository. Ubuntu-only:
    # Debian 13 removed the package, and the Debian path below doesn't need it.
    apt-get install -y -qq software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  else
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
      > /etc/apt/sources.list.d/sury-php.list
  fi

  # Node.js 22 (required to build the panel frontend)
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null

  apt-get update -qq
  apt-get install -y -qq \
    "php${PHP_VERSION}" "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-cli" "php${PHP_VERSION}-gd" \
    "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-bcmath" \
    "php${PHP_VERSION}-xml" "php${PHP_VERSION}-curl" "php${PHP_VERSION}-zip" "php${PHP_VERSION}-intl" \
    mariadb-server redis-server nginx nodejs

  npm install -g yarn >/dev/null 2>&1 || true

  # Composer 2 — bootstrapped with the pinned PHP, never the system `php`.
  resolve_php_bin
  curl -sS https://getcomposer.org/installer | "$PHP_BIN" -- --install-dir=/usr/local/bin --filename=composer

  systemctl enable --now mariadb redis-server nginx cron

  # A MariaDB that was already running keeps its old port until restarted.
  if ! ss -ltnH "sport = :$DB_PORT" 2>/dev/null | grep -q .; then
    systemctl restart mariadb
  fi
  success "Dependencies installed (PHP ${PHP_VERSION}, Node $(node -v), MariaDB on port ${DB_PORT}, Redis, nginx)"
}

# ── Database ───────────────────────────────────────────────────────────────
setup_database() {
  log "Creating panel database..."
  mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
-- Force the password on re-runs: this script generates a fresh DB_PASSWORD
-- each run, and a pre-existing user would otherwise keep the old one.
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  success "Database '${DB_NAME}' ready"
}

# ── Panel: clone + build ───────────────────────────────────────────────────
install_panel() {
  log "Cloning Touch Down Hosting panel from ${GIT_REPO}..."
  mkdir -p "$PANEL_DIR"
  # A previous run chowns the tree to www-data; git run as root then refuses
  # it (dubious ownership) unless the directory is registered as safe.
  git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$PANEL_DIR" \
    || git config --global --add safe.directory "$PANEL_DIR"
  if [ -d "${PANEL_DIR}/.git" ]; then
    git -C "$PANEL_DIR" fetch origin && git -C "$PANEL_DIR" checkout "$GIT_BRANCH" && git -C "$PANEL_DIR" pull
  else
    git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO" "$PANEL_DIR"
  fi
  cd "$PANEL_DIR"

  # Git clones do not include Laravel's runtime directories (they are ignored
  # in the repo); without them the app fails to boot with
  # "Please provide a valid cache path."
  mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views \
    storage/logs bootstrap/cache

  chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
  cp -n .env.example .env

  log "Installing PHP dependencies (composer)..."
  COMPOSER_ALLOW_SUPERUSER=1 "$PHP_BIN" /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction --quiet

  log "Building frontend assets (this fork is source-only — building on the server)..."
  yarn install --frozen-lockfile --silent
  yarn build:production >/dev/null
  success "Panel source installed and assets built"
}

configure_panel() {
  cd "$PANEL_DIR"
  log "Configuring environment..."

  # NEVER regenerate an existing APP_KEY: everything encrypted with it
  # (2FA secrets, billing keys, SMB credentials) becomes unreadable.
  if grep -q '^APP_KEY=base64:' .env 2>/dev/null; then
    log "Existing APP_KEY found — keeping it."
  else
    "$PHP_BIN" artisan key:generate --force

    # Hard-verify the encryption key actually landed in .env — everything
    # downstream depends on it, and a silent failure here surfaces later as
    # the confusing "No application encryption key has been specified." error.
    if ! grep -q '^APP_KEY=base64:' .env; then
      error "APP_KEY was not written to .env — 'php artisan key:generate' failed. Aborting."
      exit 1
    fi
    success "Application encryption key generated"
  fi

  # The scheme must match reality: Pterodactyl sets SESSION_SECURE_COOKIE=true
  # whenever APP_URL starts with https, and a Secure cookie is never sent over
  # plain HTTP — every request then gets a fresh session and login fails with
  # "CSRF token mismatch."
  "$PHP_BIN" artisan p:environment:setup \
    --author="$ADMIN_EMAIL" \
    --url="${APP_URL}" \
    --timezone="$TIMEZONE" \
    --cache="redis" \
    --session="redis" \
    --queue="redis" \
    --redis-host="localhost" \
    --redis-pass="null" \
    --redis-port="6379" \
    --settings-ui=true \
    --no-interaction

  "$PHP_BIN" artisan p:environment:database \
    --host="127.0.0.1" \
    --port="$DB_PORT" \
    --database="$DB_NAME" \
    --username="$DB_USER" \
    --password="$DB_PASSWORD" \
    --no-interaction

  # Brand the application name (shown in titles/notifications).
  grep -q '^APP_NAME=' .env && sed -i 's/^APP_NAME=.*/APP_NAME="Touch Down Hosting"/' .env || echo 'APP_NAME="Touch Down Hosting"' >> .env

  # Stamp the build identity (channel, git commit, dev feature whitelist).
  set_env() {
    local key="$1" value="$2"
    grep -q "^${key}=" .env && sed -i "s|^${key}=.*|${key}=${value}|" .env || echo "${key}=${value}" >> .env
  }
  set_env "TDH_CHANNEL" "$CHANNEL"
  set_env "TDH_BUILD" "$(git -C "$PANEL_DIR" rev-parse --short HEAD)"
  [ "$CHANNEL" = "dev" ] && set_env "DEV_FEATURES_USERS" "$DEV_FEATURES_USERS"

  log "Running database migrations (includes the Touch Down trophy system)..."
  "$PHP_BIN" artisan migrate --seed --force

  log "Creating admin user..."
  "$PHP_BIN" artisan p:user:make \
    --email="$ADMIN_EMAIL" \
    --username="$ADMIN_USERNAME" \
    --name-first="$ADMIN_FIRST" \
    --name-last="$ADMIN_LAST" \
    --password="$ADMIN_PASSWORD" \
    --admin=1 \
    --no-interaction \
    || log "Admin user already exists — skipping (use reset-master-password.sh to change its password)."

  chown -R www-data:www-data "$PANEL_DIR"
  # .env holds APP_KEY and database credentials — keep it out of reach of
  # other local users.
  chmod 600 "$PANEL_DIR/.env"

  # www-data must be able to traverse EVERY parent directory of the panel.
  # Home directories are mode 0750 on Ubuntu >=21.04 / Debian >=12, so a panel
  # installed under /home is unreachable by the web server until the search
  # bit is granted — the failure looks like php-fpm's "File not found.".
  # o+x grants path resolution only; directory contents stay unlistable.
  local dir="$PANEL_DIR"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if ! runuser -u www-data -- test -x "$dir" 2>/dev/null; then
      chmod o+x "$dir" 2>/dev/null && log "Granted www-data traverse access to ${dir}"
    fi
    dir="$(dirname "$dir")"
  done
  if ! runuser -u www-data -- test -r "${PANEL_DIR}/public/index.php" 2>/dev/null; then
    error "www-data still cannot read ${PANEL_DIR}/public/index.php."
    error "Run installer/repair-touchdown-panel.sh after this finishes."
  fi

  success "Panel configured"
}

# ── Services: cron, queue worker, nginx, SSL ───────────────────────────────
setup_services() {
  log "Installing cron schedule and queue worker..."

  # systemd and cron need an absolute path to PHP; a path that does not exist
  # fails with 203/EXEC and the unit never starts.
  resolve_php_bin

  # Never sort a crontab — environment assignments (PATH, MAILTO) are positional.
  # Read the existing crontab OUTSIDE the pipeline: when the user has no
  # crontab yet the read exits 1, and under set -e/pipefail that aborted the
  # whole installer right here — silently.
  existing_cron="$(crontab -u www-data -l 2>/dev/null || true)"
  { printf '%s\n' "$existing_cron" | grep -v 'artisan schedule:run' || true
    echo "* * * * * ${PHP_BIN} ${PANEL_DIR}/artisan schedule:run >> /dev/null 2>&1"
  } | grep -v '^$' | crontab -u www-data -

  cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Touch Down Hosting Panel Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=${PHP_BIN} ${PANEL_DIR}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now pteroq.service

  log "Configuring nginx..."
  rm -f /etc/nginx/sites-enabled/default

  cat > /etc/nginx/sites-available/touchdown.conf <<EOF
server {
    listen ${PANEL_PORT};
    server_name ${FQDN};

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
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
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

    location ~ /\.ht {
        deny all;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/touchdown.conf /etc/nginx/sites-enabled/touchdown.conf
  # Reload, not restart: nginx may also be serving another web UI on this
  # host (e.g. OpenMediaVault) — a reload adds our site with zero downtime.
  nginx -t && { systemctl reload nginx || systemctl restart nginx; }

  if [ "$CONFIGURE_SSL" = "yes" ]; then
    log "Requesting Let's Encrypt certificate for ${FQDN}..."
    apt-get install -y -qq certbot python3-certbot-nginx
    certbot --nginx --redirect -d "$FQDN" -m "$ADMIN_EMAIL" --agree-tos -n || {
      error "certbot failed — the panel is still reachable over HTTP; re-run certbot manually once DNS resolves."
    }
  fi
  success "Services configured"
}

# ── Auto-update (systemd timer; default: on for dev, off for public) ──────
setup_auto_update() {
  if [ "$AUTO_UPDATE" != "yes" ]; then
    log "Auto-update disabled for this ${CHANNEL} install — update manually with:"
    log "  bash ${PANEL_DIR}/installer/update-touchdown-panel.sh"
    return
  fi

  log "Enabling nightly auto-update (${GIT_BRANCH} branch)..."
  cat > /etc/systemd/system/touchdown-update.service <<EOF
[Unit]
Description=Touch Down Hosting panel auto-update (${CHANNEL} channel)
After=network-online.target

[Service]
Type=oneshot
Environment=PANEL_DIR=${PANEL_DIR}
Environment=GIT_BRANCH=${GIT_BRANCH}
ExecStart=/bin/bash ${PANEL_DIR}/installer/update-touchdown-panel.sh
EOF

  cat > /etc/systemd/system/touchdown-update.timer <<EOF
[Unit]
Description=Nightly Touch Down Hosting panel auto-update

[Timer]
OnCalendar=*-*-* 04:30:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now touchdown-update.timer
  success "Auto-update timer active (nightly at ~04:30 server time)"
}

summary() {
  echo
  echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${WHITE}  Touch Down Hosting panel installed successfully!${RESET}"
  echo -e "${ORANGE}══════════════════════════════════════════════════════════════${RESET}"
  echo -e "  Panel URL:      ${WHITE}${APP_URL}${RESET}"
  echo -e "  Build channel:  ${WHITE}${CHANNEL} (${GIT_BRANCH} branch, auto-update: ${AUTO_UPDATE})${RESET}"
  echo -e "  Admin login:    ${WHITE}${ADMIN_USERNAME} / ${ADMIN_EMAIL}${RESET}"
  echo -e "  Install path:   ${WHITE}${PANEL_DIR}${RESET}"
  echo -e "  DB credentials: ${WHITE}${DB_USER} / ${DB_PASSWORD}${RESET}  (database: ${DB_NAME}, host: 127.0.0.1:${DB_PORT})"
  echo
  echo -e "  Next steps:"
  echo -e "   1. Log in and check the pulsating-logo login flow + Cool Orange theme."
  echo -e "   2. Install Wings on your game nodes (unmodified — use the official"
  echo -e "      installer: https://pterodactyl-installer.se)."
  echo -e "   3. Add custom themes any time: drop .json files in ${PANEL_DIR}/public/themes/"
  echo -e "   4. Publish Dev-Blog posts by editing resources/scripts/touchdown/devblogs.ts"
  echo -e "      in your repo, then: git pull && yarn build:production (in ${PANEL_DIR})"
  echo
}

# A COMPLETED install (APP_KEY present in .env) must be updated with the
# update script, not reinstalled — this installer exists for fresh installs
# and for resuming one that failed part-way. Guarding here protects a live
# panel from an accidental re-install.
guard_existing_install() {
  grep -q '^APP_KEY=base64:' "${PANEL_DIR}/.env" 2>/dev/null || return 0
  echo
  log "An existing panel installation was detected at ${PANEL_DIR}."
  echo "  To UPDATE it, use the update script instead:"
  echo "      sudo bash ${PANEL_DIR}/installer/update-touchdown-panel.sh"
  echo "  Only continue if you know this install is broken and want to repair"
  echo "  it in place. Your database, .env and encryption key are preserved"
  echo "  either way — but updating is the right tool for a working panel."
  echo
  read -rp "Continue with the installer anyway? [y/N] " goon
  [[ "$goon" =~ ^[Yy]$ ]] || { log "Aborted — nothing was changed."; exit 0; }
}

# ── Main ───────────────────────────────────────────────────────────────────
banner
require_root
detect_os
guard_existing_install
prompt_config
install_dependencies
setup_database
install_panel
configure_panel
setup_services
setup_auto_update
summary
