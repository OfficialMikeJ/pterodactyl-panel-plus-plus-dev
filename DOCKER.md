# Touch Down Hosting — Docker / Docker Compose Install

Runs the panel, MariaDB and Redis as containers. This is an **alternative** to
the bare-metal installer in [`installer/`](installer/README.md) — pick one, not
both, per server.

Because this fork is source-only, the panel image is **built from your clone**
— the branch you check out is the build you deploy:

| Build | Branch | Clone from |
| --- | --- | --- |
| Public | `main` | your GitHub repository |
| Dev (internal) | `dev` | your Gitea repository |

## Prerequisites

Docker Engine + the compose plugin on the host:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo docker run --rm hello-world      # sanity check
```

> Ubuntu 24.04 note: if this collides with Ubuntu's own docker packages
> (`trying to overwrite '/usr/libexec/docker/cli-plugins/docker-compose'`),
> remove them first: `sudo apt-get remove -y docker-compose-v2 containerd`
> then re-run the install script.

## Install

```bash
# 1. Clone the branch for the build you want (dev shown; use your GitHub URL + main for public)
git clone --branch dev https://repo.tieronerepository.dev/TouchDownEntertainment/Pterodactyl-Plus-Plus.git /srv/touchdown-panel
cd /srv/touchdown-panel

# 2. Create your compose file from the example and edit it
cp docker-compose.example.yml docker-compose.yml
nano docker-compose.yml
```

Set at minimum:

- `MYSQL_PASSWORD` and `MYSQL_ROOT_PASSWORD` — real random passwords
- `APP_URL` — how browsers reach the panel (`http://192.168.x.x` on a LAN,
  `https://panel.example.com` behind TLS). **The scheme matters**: `https`
  turns on Secure session cookies, which break login if you actually serve
  plain HTTP ("CSRF token mismatch").
- `TDH_CHANNEL` — `public` or `dev`; on dev also uncomment
  `DEV_FEATURES_USERS` with the whitelisted emails
- Ports, if 80/443 are taken on the host — e.g. `"8080:80"` (see reverse proxy
  section below)

```bash
# 3. Build and start (first build compiles the frontend — takes several minutes)
docker compose up -d --build

# 4. Watch the first boot: it generates APP_KEY, waits for the DB,
#    migrates and seeds automatically
docker compose logs -f panel        # Ctrl+C to stop watching

# 5. Create your admin account
docker compose exec panel php artisan p:user:make
```

Open `APP_URL` in a browser — you should get the glass login screen.

## Updating

```bash
cd /srv/touchdown-panel
git pull
docker compose up -d --build
```

Migrations run automatically on boot. Seeding does **not** re-run (it would
overwrite admin egg customisations); delete `/srv/pterodactyl/var/.seeded` if
you ever want to force a re-seed.

## Where your data lives

Everything that must survive rebuilds is on the host under `/srv/pterodactyl/`:
`database/` (MariaDB), `var/` (the panel's `.env` — **contains APP_KEY, back
this up**), `logs/`, `certs/`, `nginx/`. Containers and images are disposable.

## Behind Nginx Proxy Manager / a reverse proxy

If another machine (or container) owns ports 80/443, map the panel elsewhere in
`docker-compose.yml`:

```yaml
    ports:
      - "8080:80"
```

Point the proxy host at `this-machine-ip:8080` (scheme `http`), terminate TLS
at the proxy, and set `APP_URL` to the `https://` domain. Do not set `LE_EMAIL`
in that setup — the proxy owns the certificates.

## Wings

Wings is **not** part of this compose file and is unmodified in this fork —
install it on game nodes with the official tooling
(<https://pterodactyl-installer.se>). Wings manages its own containers and
needs the host's Docker directly; panel and Wings can share a host, but keep
their installs separate.

## Fork-specific notes

- **Logo**: mount your PNG over `/app/public/logo.png` (commented example in
  the compose file) or rebuild after replacing the file in the repo.
- **Custom themes**: theme JSONs live inside the image. To add themes without
  rebuilding, use the commented themes volume — but copy the four built-in
  JSONs into the host folder first, or they disappear from the picker.
- **Dev-Blogs / roadmap / trophies**: these are source files — edit, commit,
  `git pull` + rebuild to publish, same as the bare-metal flow.
- The bare-metal repair script (`installer/repair-touchdown-panel.sh`) does
  **not** apply to Docker installs; use `docker compose logs panel` for
  diagnosis instead.
