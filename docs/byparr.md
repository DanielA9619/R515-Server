# Byparr

This document tracks the Byparr helper service added to the R515 Docker stack.

## Current status

Byparr has been added as an internal Docker service on `docker01`.

Access / service endpoint:

```text
http://192.168.10.135:8191
```

Container/service purpose:

```text
Internal helper service for supported Prowlarr/indexer integrations.
```

Recent recovery note:

- Byparr stopped working for Prowlarr/indexer tests and returned `500 Internal Server Error` through `http://192.168.10.135:8191/v1`.
- Logs showed an internal Camoufox/Playwright process-spawn failure: `BlockingIOError: [Errno 11] Resource temporarily unavailable`.
- A hard remove/recreate pulled Byparr forward to version `3.0.4` and restored `/health`.
- After Byparr recovered, restart Prowlarr and retest the Prowlarr indexer proxy/indexers.

## Network and security

- Keep Byparr LAN-only.
- Do not port forward `8191` publicly.
- Do not expose Byparr through Caddy or a public hostname unless remote access is intentionally redesigned and protected.
- Keep credentials, API keys, and private tokens out of GitHub.
- Do not make Byparr a dependency for every indexer unless it is actually needed; direct indexers are usually more stable.

## Related services

- Prowlarr: `http://192.168.10.135:9696`
- Radarr: `http://192.168.10.135:7878`
- Sonarr: `http://192.168.10.135:8989`
- qBittorrent: `http://192.168.10.135:8080`

## Docker notes

Expected Docker Compose pattern:

```yaml
  byparr:
    image: ghcr.io/thephaseless/byparr:latest
    restart: unless-stopped
    dns:
      - 192.168.10.135
    environment:
      - TZ=America/Denver
    ports:
      - "8191:8191"
```

The explicit DNS entry matches the fix used for Prowlarr, where Docker's default internal resolver had problems but direct DNS to AdGuard at `192.168.10.135` worked.

## Quick checks

Basic container checks:

```bash
cd /srv/docker
sudo docker compose ps byparr prowlarr
sudo docker compose logs byparr --tail=100
```

Health check:

```bash
curl -i http://192.168.10.135:8191/health
```

Expected healthy response pattern:

```text
HTTP/1.1 200 OK
{"msg":"Byparr is working!","version":"3.0.4", ...}
```

Basic API-style test:

```bash
curl -i -X POST http://192.168.10.135:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd":"request.get","url":"https://example.com","maxTimeout":60000}' | head -80
```

If the API-style test returns `500`, Byparr itself is failing. If it succeeds but Prowlarr still fails, check the Prowlarr indexer proxy settings.

## Streamlined recovery procedure

Use this when Prowlarr reports Byparr-related `500` errors or indexer proxy tests suddenly fail.

### 1. Confirm Byparr is the failing layer

```bash
cd /srv/docker
sudo docker compose ps byparr prowlarr
curl -i http://192.168.10.135:8191/health
sudo docker compose logs byparr --tail=120
```

Signs this is a Byparr issue:

```text
Prowlarr error mentions http://192.168.10.135:8191/v1
Byparr /health returns 500 or health stays stuck
Logs show Camoufox/Playwright/subprocess errors
```

### 2. Hard recreate Byparr only

```bash
cd /srv/docker
sudo docker compose stop byparr
sudo docker compose rm -f byparr
sudo docker compose pull byparr
sudo docker compose up -d byparr
```

### 3. Verify recovery

```bash
curl -i http://192.168.10.135:8191/health
sudo docker compose ps byparr
sudo docker compose logs byparr --tail=80
```

If Docker still says `health: starting`, check the healthcheck interval before assuming it is broken:

```bash
sudo docker inspect docker-byparr-1 --format '{{json .Config.Healthcheck}}'
```

A long interval can make the container look like it is still starting even after `/health` is already working.

### 4. Restart and retest Prowlarr

```bash
cd /srv/docker
sudo docker compose restart prowlarr
```

Then in Prowlarr:

```text
Settings -> Indexers -> Indexer Proxies -> Test Byparr proxy
Indexers -> Test All
```

If Byparr passes but only certain indexers fail, treat those indexers as the problem. Disable Byparr for indexers that do not need it.

## Monitoring

Recommended Uptime Kuma monitor:

```text
Name: Byparr
Type: HTTP(s)
URL: http://192.168.10.135:8191/health
```

Add it to the R515 status page if it is part of the active stack.

## Backup

After confirming the service works, include it in the next `/srv/docker` backup:

```bash
cd /srv/docker
/srv/docker/scripts/backup-r515-configs.sh after-byparr-recovery
```
