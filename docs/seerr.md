# Seerr

This document tracks the Seerr media request frontend added to the R515 Docker stack.

## Current status

Seerr has been added as a LAN-only Docker service on `docker01`.

Access URL:

```text
http://192.168.10.135:5055
```

Purpose:

```text
LAN-only movie and TV request frontend that connects Jellyfin, Radarr, and Sonarr.
```

Current setup state:

- Seerr is installed and reachable on port `5055`.
- Jellyfin connection is configured.
- Jellyfin external URL is `https://mediahubdaniel.duckdns.org`.
- Radarr connection is configured.
- Sonarr connection is configured.
- Radarr and Sonarr use quality profiles that allow 1080p fallback with 4K upgrades.
- User confirmed Seerr requests work.
- Uptime Kuma monitor URL typo was fixed from port `505` to port `5055`.

## Connected services

Seerr should connect to:

| Service | URL / settings |
| --- | --- |
| Jellyfin internal URL | `http://192.168.10.135:8096` |
| Jellyfin external URL | `https://mediahubdaniel.duckdns.org` |
| Radarr | `http://192.168.10.135:7878` |
| Sonarr | `http://192.168.10.135:8989` |

For Radarr and Sonarr:

- Use the normal single Radarr/Sonarr instances.
- Keep `4K Server` disabled unless separate 4K-only instances are created later.
- Use quality profiles that allow 1080p fallback with 4K upgrades.
- Radarr root folder: `/movies`.
- Sonarr root folder: `/tv`.

## Network and security

- Keep Seerr LAN-only for now.
- Do not port forward `5055` publicly.
- Do not expose Seerr through Caddy or a public hostname until remote access is intentionally redesigned and protected.
- Use a unique admin password.
- Keep API keys and passwords out of GitHub.

## Docker notes

Expected Docker Compose pattern:

```yaml
  seerr:
    image: ghcr.io/seerr-team/seerr:latest
    container_name: seerr
    init: true
    restart: unless-stopped
    dns:
      - 192.168.10.135
    environment:
      - TZ=America/Denver
      - PORT=5055
    ports:
      - "5055:5055"
    volumes:
      - /srv/docker/seerr/config:/app/config
```

## Validation checklist

1. Open `http://192.168.10.135:5055`.
2. Confirm Jellyfin connection works. - Done.
3. Confirm Radarr connection works. - Done.
4. Confirm Sonarr connection works. - Done.
5. Request one controlled movie using content the user has rights to access. - User confirmed requests work.
6. Confirm Radarr receives the request.
7. Confirm qBittorrent starts the download through Gluetun.
8. Confirm Radarr imports the completed file into `/mnt/storage/media/movies`.
9. Confirm Jellyfin sees the movie after a scan.
10. Request one controlled TV item using content the user has rights to access. - User confirmed requests work.
11. Confirm Sonarr imports the completed file into `/mnt/storage/media/tv`.
12. Add Seerr to Homarr.
13. Add Seerr to Uptime Kuma. - Monitor created; URL corrected to `http://192.168.10.135:5055`.
14. Back up `/srv/docker`.

## Monitoring

Recommended Uptime Kuma monitor:

```text
Name: Seerr
Type: HTTP(s)
URL: http://192.168.10.135:5055
Accepted Status Codes: 200-399
```

A previous typo used port `505`, which left the monitor pending/down. Correct port is `5055`.

## Torrent health notes

The stack works, but the user is seeing some downloads stall with no connections. This is usually a release/indexer health issue rather than a Seerr issue.

Recommended tuning:

- Prefer manual search while testing.
- Prefer releases with real seeders.
- Raise minimum seeders in Prowlarr sync/indexer settings where available.
- Sort public/noisy indexers by seeders descending when supported.
- Leave indexers with sorting warnings on defaults unless they repeatedly produce bad results.
- Keep qBittorrent speed limits off unless upload saturation causes issues.

## Backup

After confirming the service works, include it in the next `/srv/docker` backup:

```bash
cd /srv/docker
TODAY=$(date +%F)
sudo mkdir -p /mnt/storage/backups/$TODAY
sudo tar -czf /mnt/storage/backups/$TODAY/srv-docker-after-seerr.tar.gz /srv/docker
```

## Future SMS bot connection

The future SMS request bot should submit media requests into Seerr rather than talking directly to Radarr/Sonarr first. This keeps the request workflow cleaner and preserves approval/user tracking in one place.
