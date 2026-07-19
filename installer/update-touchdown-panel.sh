#!/bin/bash
set -euo pipefail

#############################################################################
#  Touch Down Hosting Panel Updater                                         #
#                                                                           #
#  Pulls the latest panel code, rebuilds the frontend assets and applies    #
#  migrations. Run as root on the panel host:                               #
#                                                                           #
#      sudo bash installer/update-touchdown-panel.sh                        #
#      sudo bash installer/update-touchdown-panel.sh --seed   # + eggs      #
#                                                                           #
#  The panel directory and branch are auto-detected, so a dev-channel       #
#  install is never silently switched to the public branch. Maintenance     #
#  mode is always lifted, even if the update fails part-way.                #
#############################################################################

ALLOW_SEED="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --seed) ALLOW_SEED="yes" ;;
    -h|--help) sed -n '4,16p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1 (valid: --seed)" >&2; exit 2 ;;
  esac
  shift
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash $0)" >&2
  exit 1
fi

# ── Locate the panel: explicit PANEL_DIR, else the tree this script lives in ─
if [ -n "${PANEL_DIR:-}" ] && [ -f "${PANEL_DIR}/artisan" ]; then
  PANEL_DIR="$(cd "$PANEL_DIR" && pwd -P)"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  if [ -f "$(dirname "$SCRIPT_DIR")/artisan" ]; then
    PANEL_DIR="$(dirname "$SCRIPT_DIR")"
  else
    echo "No panel found. Set PANEL_DIR=/path/to/panel and re-run." >&2
    exit 1
  fi
fi

cd "$PANEL_DIR"

# ── Discover the php-fpm pool user and PHP version (never assume) ──────────
PHP_VER="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
FPM_USER="$(awk -F= '/^[[:space:]]*user[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2;exit}' \
    "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" 2>/dev/null || true)"
FPM_USER="${FPM_USER:-www-data}"
PHP="${PHP:-php}"

# ── Branch: follow the branch this install is ALREADY on ──────────────────
# Defaulting to "main" would silently downgrade a dev-channel panel to the
# public build (and run its migrations on top).
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
GIT_BRANCH="${GIT_BRANCH:-$CURRENT_BRANCH}"
if [ -z "$GIT_BRANCH" ] || [ "$GIT_BRANCH" = "HEAD" ]; then
  echo "Cannot determine the current branch — set GIT_BRANCH=dev (or main) and re-run." >&2
  exit 1
fi

echo "[Touch Down] Panel:  ${PANEL_DIR}"
echo "[Touch Down] Branch: ${GIT_BRANCH} (channel: $(grep -E '^TDH_CHANNEL=' .env 2>/dev/null | cut -d= -f2 || echo unknown))"
echo "[Touch Down] User:   ${FPM_USER}"

# Always leave maintenance mode, however this script exits.
cleanup() {
  local rc=$?
  echo "[Touch Down] Leaving maintenance mode..."
  $PHP artisan up >/dev/null 2>&1 || true
  [ "$rc" -ne 0 ] && echo "[Touch Down] Update FAILED (exit $rc) — the panel is back up on the previous code." >&2
  exit "$rc"
}
trap cleanup EXIT INT TERM

echo "[Touch Down] Entering maintenance mode..."
$PHP artisan down >/dev/null 2>&1 || true

echo "[Touch Down] Pulling latest code (${GIT_BRANCH})..."
git fetch origin
git checkout "$GIT_BRANCH"
git pull origin "$GIT_BRANCH"

echo "[Touch Down] Updating PHP dependencies..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --quiet

echo "[Touch Down] Rebuilding frontend assets..."
# build:production deletes the existing bundles first, so keep a copy — a failed
# build would otherwise leave a white page where a working UI stood.
ASSET_BAK="$(mktemp -d)"
cp -a public/assets "$ASSET_BAK/" 2>/dev/null || true
if yarn install --frozen-lockfile --silent && yarn build:production >/dev/null; then
  rm -rf "$ASSET_BAK"
else
  echo "[Touch Down] Asset build failed — restoring the previous assets." >&2
  rm -rf public/assets && cp -a "$ASSET_BAK/assets" public/assets && rm -rf "$ASSET_BAK"
  exit 1
fi

echo "[Touch Down] Stamping build id..."
BUILD_HASH="$(git rev-parse --short HEAD)"
if grep -q '^TDH_BUILD=' .env; then
  sed -i "s/^TDH_BUILD=.*/TDH_BUILD=${BUILD_HASH}/" .env
else
  echo "TDH_BUILD=${BUILD_HASH}" >> .env
fi

echo "[Touch Down] Clearing caches and running migrations..."
$PHP artisan view:clear
$PHP artisan config:clear
# Schema only. Seeding re-imports the bundled eggs and would overwrite admin
# customisations to startup commands, Docker images and install scripts.
$PHP artisan migrate --force
if [ "$ALLOW_SEED" = "yes" ]; then
  echo "[Touch Down] Seeding: stock eggs WILL be reset to bundled defaults."
  $PHP artisan db:seed --force
fi

# Ownership last: composer/yarn/artisan above ran as root and created
# root-owned artifacts (notably storage/logs/laravel.log) that would 500.
chown -R "${FPM_USER}:${FPM_USER}" "$PANEL_DIR"
find "$PANEL_DIR" -type d -exec chmod 755 {} + 2>/dev/null || true
find "$PANEL_DIR" -type f -exec chmod 644 {} + 2>/dev/null || true
chmod 755 "$PANEL_DIR/artisan" 2>/dev/null || true
find "$PANEL_DIR/installer" -name '*.sh' -exec chmod 755 {} + 2>/dev/null || true
[ -f "$PANEL_DIR/.env" ] && chmod 600 "$PANEL_DIR/.env"

echo "[Touch Down] Restarting queue worker..."
$PHP artisan queue:restart >/dev/null 2>&1 || true
systemctl restart pteroq.service 2>/dev/null || true

echo "[Touch Down] Update complete — build ${BUILD_HASH} on ${GIT_BRANCH}."
