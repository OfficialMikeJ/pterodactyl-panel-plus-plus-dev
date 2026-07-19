# Touch Down Hosting — Panel Installer

Automated install/update scripts for the Touch Down Hosting panel (Pterodactyl
1.14.1 fork), modeled on the
[pyrodactyl-installer](https://github.com/Muspelheim-Hosting/pyrodactyl-installer) /
[pterodactyl-installer](https://pterodactyl-installer.se) projects.

The key difference from those installers: this repository is **source-only**
(no pre-built `panel.tar.gz` releases), so the installer clones your git
repository (e.g. your Gitea instance) and builds the frontend assets on the
server with Node.js 22 + Yarn.

## Supported systems

- Ubuntu 22.04 / 24.04
- Debian 11 / 12

## Fresh install

On a fresh server, as root:

```bash
apt-get update && apt-get install -y git
git clone https://YOUR-GITEA-HOST/YourUser/touch-down-hosting-panel.git /tmp/tdh
bash /tmp/tdh/installer/install-touchdown-panel.sh
```

The script prompts for everything it needs (repo URL, panel domain, admin
credentials). You can also pre-answer via environment variables:

```bash
GIT_REPO="https://YOUR-GITEA-HOST/YourUser/touch-down-hosting-panel.git" \
FQDN="panel.example.com" \
ADMIN_EMAIL="you@example.com" \
ADMIN_PASSWORD="********" \
CONFIGURE_SSL="yes" \
bash /tmp/tdh/installer/install-touchdown-panel.sh
```

What it sets up:

| Component | Details |
| --- | --- |
| PHP 8.3 + extensions | fpm, cli, gd, mysql, mbstring, bcmath, xml, curl, zip, intl |
| MariaDB | `panel` database + dedicated user with random password |
| Redis | cache / sessions / queue |
| Node.js 22 + Yarn | builds the panel frontend (`yarn build:production`) |
| nginx | site config for your FQDN, optional Let's Encrypt via certbot |
| systemd | `pteroq.service` queue worker |
| cron | Laravel scheduler for `www-data` |
| Panel | migrations (incl. trophy system), admin user, `APP_NAME` branding |

## Build channels

The installer asks which channel a server belongs to:

| Channel | Branch | Who | Updates |
| --- | --- | --- | --- |
| `public` | `main` | Customers — the Alpha build with the version badge | Manual (run the update script) |
| `dev` | `dev` | You — internal build with the Dev Lab tab | Manual (run the update script) |

On the dev channel the installer also asks for `DEV_FEATURES_USERS` — the
comma-separated emails allowed to see dev-only features. The public build
never exposes dev features regardless of that list.

The installed commit is stamped into `.env` as `TDH_BUILD` and shown on the
panel's Dev-Blogs page under **Current Build**.

## Updating an existing install

```bash
bash /var/www/touchdown/installer/update-touchdown-panel.sh
```

Pulls the latest code from the server's branch, reinstalls dependencies,
rebuilds assets, migrates the database, re-stamps the build hash and restarts
the queue worker (with maintenance mode around it).

Scheduled auto-update is **disabled by default** for both channels. To opt a
server into a nightly automatic update, install with `AUTO_UPDATE=yes` — that
creates a `touchdown-update.timer` systemd unit (check it with
`systemctl status touchdown-update.timer`).

## Repairing a broken or half-finished install

```bash
sudo bash installer/repair-touchdown-panel.sh            # check + auto-fix
sudo bash installer/repair-touchdown-panel.sh --check    # report only, change nothing
sudo PANEL_DIR=/path/to/panel bash installer/repair-touchdown-panel.sh
```

Finds the panel automatically and checks every subsystem, fixing what it can:

| Area | Checks / fixes |
| --- | --- |
| `.env` | Present, `APP_KEY` generated (works even when Laravel cannot boot), `APP_URL` sane (no `https` on a bare IP), mode 600 |
| Filesystem | Laravel runtime directories, `www-data` ownership, storage permissions |
| Dependencies | `vendor/` (composer), built frontend assets (yarn) |
| Services | mariadb, redis, nginx, PHP-FPM running |
| Database | Connection works, pending migrations applied |
| Web server | Panel site exists + enabled, **nginx's default site removed** (the classic "Welcome to nginx!" page), config valid, reload |
| Workers | `pteroq` queue worker, scheduler cron entry |
| Result | Final HTTP check plus the address the panel is reachable on |

It never deletes data and never touches database contents, so it is safe to
run repeatedly.

## Wings

Wings is **unmodified** in this fork — install it on your game nodes with the
official installer: <https://pterodactyl-installer.se>
