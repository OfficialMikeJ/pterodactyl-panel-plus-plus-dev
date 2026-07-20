#!/bin/bash
set -euo pipefail

#############################################################################
#  Touch Down Hosting — Store Git Credentials (one time)                    #
#                                                                           #
#  Saves your repository credentials on THIS SERVER so git never prompts    #
#  again — no more username/password every time you pull or update.         #
#                                                                           #
#      sudo bash installer/setup-git-credentials.sh                         #
#                                                                           #
#  Or non-interactively:                                                    #
#      sudo GIT_USERNAME=you GIT_TOKEN=xxxx bash installer/setup-git-credentials.sh
#                                                                           #
#  Credentials are written to /root/.git-credentials (mode 600, root only), #
#  deliberately OUTSIDE the panel directory — so the repository, the web    #
#  root, `git remote -v` and .env never contain them.                       #
#                                                                           #
#  A Gitea ACCESS TOKEN (Settings -> Applications -> Generate New Token,    #
#  scope read:repository) is recommended over an account password: it is    #
#  read-only, revocable on its own, and works when 2FA is enabled.          #
#############################################################################

ORANGE='\033[38;5;208m'; GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
log()  { echo -e "${ORANGE}[Touch Down]${RESET} $1"; }
ok()   { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
fail() { echo -e "${RED}[ERROR ]${RESET} $1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Run as root (sudo bash $0)"

GIT_USERNAME="${GIT_USERNAME:-}"
GIT_TOKEN="${GIT_TOKEN:-}"
REPO_URL="${REPO_URL:-}"

# Find the repository URL from the panel this script lives in, unless given.
if [ -z "$REPO_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  PANEL_DIR="$(dirname "$SCRIPT_DIR")"
  if [ -d "${PANEL_DIR}/.git" ]; then
    REPO_URL="$(git -C "$PANEL_DIR" remote get-url origin 2>/dev/null || true)"
  fi
fi
[ -n "$REPO_URL" ] || read -rp "Repository URL (https://host/user/repo.git): " REPO_URL

case "$REPO_URL" in
  https://*|http://*) ;;
  *) fail "Only http(s) remotes need stored credentials. SSH remotes use keys instead." ;;
esac

PROTO="${REPO_URL%%://*}"
HOST="${REPO_URL#*://}"; HOST="${HOST%%/*}"; HOST="${HOST##*@}"

log "Repository host: ${HOST}"
[ -n "$GIT_USERNAME" ] || read -rp "Git username: " GIT_USERNAME
if [ -z "$GIT_TOKEN" ]; then
  echo "Paste an access token (recommended) or your password — input is hidden."
  read -rsp "Git token/password: " GIT_TOKEN; echo
fi
[ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ] || fail "Username and token are both required."

# `git credential approve` handles escaping/encoding correctly — safer than
# hand-building a URL when the token contains special characters.
git config --global credential.helper store
printf 'protocol=%s\nhost=%s\nusername=%s\npassword=%s\n\n' \
  "$PROTO" "$HOST" "$GIT_USERNAME" "$GIT_TOKEN" | git credential approve

[ -f /root/.git-credentials ] && chmod 600 /root/.git-credentials
ok "Credentials stored in /root/.git-credentials (mode 600, root only)"

# Also let git operate on the panel directory even though it is owned by www-data.
if [ -n "${PANEL_DIR:-}" ] && [ -d "${PANEL_DIR}/.git" ]; then
  git config --global --add safe.directory "$PANEL_DIR" 2>/dev/null || true
fi

log "Verifying access (this should NOT prompt)..."
if GIT_TERMINAL_PROMPT=0 git ls-remote "$REPO_URL" HEAD >/dev/null 2>&1; then
  ok "Repository access confirmed — git will no longer ask for credentials."
  echo
  echo "  Updates from now on are just:"
  echo "      sudo bash ${PANEL_DIR:-/path/to/panel}/installer/update-touchdown-panel.sh"
else
  fail "Still cannot read ${REPO_URL}. Check the username/token and that the token has repository read access."
fi
