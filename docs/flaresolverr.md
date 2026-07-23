# FlareSolverr

This document tracks the FlareSolverr helper service added to the R515 Docker stack.

## Current status

FlareSolverr has been added as an internal Docker service on `docker01`.

Access / service endpoint:

```text
http://192.168.10.135:8191
```

Container/service purpose:

```text
Internal helper service for supported Prowlarr/indexer integrations.
```

## Network and security

- Keep FlareSolverr LAN-only.
- Do not port forward `8191` publicly.
- Do not expose FlareSolverr through Caddy or a public hostname unless remote access is intentionally redesigned and protected.
- Keep credentials, API keys, and private tokens out of GitHub.

## Related services

- Prowlarr: `http://192.168.10.135:9696`
- Radarr: `http://192.168.10.135:7878`
- Sonarr: `http://192.168.10.135:8989`
- qBittorrent: `http://192.168.10.135:8080`

## Docker notes

Expected Docker Compose pattern:

```yaml
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    restart: unless-stopped
    dns:
      - 192.168.10.135
    environment:
      - TZ=America/Denver
    ports:
      - "8191:8191"
```

The explicit DNS entry matches the fix used for Prowlarr, where Docker's default internal resolver had problems but direct DNS to AdGuard at `192.168.10.135` worked.

## Checks

Basic container checks:

```bash
cd /srv/docker
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker logs flaresolverr --tail=80
```

Basic network check from the container network:

```bash
docker run --rm --network=container:flaresolverr busybox nslookup google.com
```

## Monitoring

Recommended Uptime Kuma monitor:

```text
Name: FlareSolverr
Type: HTTP(s)
URL: http://192.168.10.135:8191
```

Add it to the R515 status page if it is part of the active stack.

## Backup

After confirming the service works, include it in the next `/srv/docker` backup:

```bash
cd /srv/docker
TODAY=$(date +%F)
sudo mkdir -p /mnt/storage/backups/$TODAY
sudo tar -czf /mnt/storage/backups/$TODAY/srv-docker-after-flaresolverr.tar.gz /srv/docker
```
