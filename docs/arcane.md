# Arcane update dashboard

Arcane is the R515 Docker update/management dashboard.

## Design

- Manager image: `ghcr.io/getarcaneapp/manager:v2`
- Private URL: `https://arcane.r515.allenfamhouse.com`
- Caddy private-only gate; no WAN port forwarding.
- Project discovery: `/srv/docker`
- Arcane state: `/srv/docker/arcane/data`
- Secrets: `/srv/docker/arcane/.env` (never commit)
- Backup target: `/mnt/storage/backups/arcane`
- Time zone: `America/Denver`
- Docker API access is through `wollomatic/socket-proxy`, not a direct Docker socket mount in Arcane.

## Update policy

Start with manual installation only:

- Image Update Watcher: enabled, hourly.
- Auto Update: disabled.
- Event-driven checks: disabled initially.
- Review pending updates on Arcane's Updates page and apply with explicit confirmation.
- Keep Gluetun/qBittorrent, Caddy, monitoring, and other dependency-sensitive services manual unless explicitly tested for scheduled updates.

Arcane can later use cron-based Auto Update schedules and per-container exclusions/delays.

## Notifications

Use the existing private R515 Alerts ntfy topic for:

- Image Update Detected
- Container Updated
- Auto-Heal Restart only if auto-heal is later enabled

Do not commit the ntfy topic or credentials.

## First login

The upstream initial credentials are `arcane` / `arcane-admin`. Change the password immediately after first login.

## Installer

Run `scripts/install-arcane-update-dashboard.sh` as root on Docker01.

The installer:

1. detects Caddy's Docker network and trusted-proxy CIDR;
2. generates Arcane's encryption key and admin API key locally;
3. deploys a restricted Docker socket proxy and Arcane;
4. mounts `/srv/docker` for project discovery/management;
5. adds the private Caddy route using candidate validation and in-place Caddyfile overwrite;
6. verifies Arcane health and the private HTTPS route.

## Caddy safety

The live Caddyfile is a single-file bind mount. Do not replace its inode. Validate a candidate first, overwrite the existing file contents in place, then reload Caddy with `SIGUSR1`.
