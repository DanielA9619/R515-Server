# Byparr

This document tracks the Byparr helper service used by Prowlarr/indexer integrations on the R515 Docker stack.

## Current status

Byparr runs as an internal Docker service on `docker01`.

Access / service endpoint:

```text
http://192.168.10.135:8191
```

Container/service purpose:

```text
Internal helper service for supported Prowlarr/indexer integrations.
```

Current validated state:

```text
Byparr version:        3.0.4
Real /health endpoint: HTTP 200
Prowlarr indexers:     all green after recovery
```

## September 2026 outage findings

The post-outage failure had two distinct stages.

First, Byparr had previously experienced an internal Camoufox/Playwright process-spawn failure (`BlockingIOError: [Errno 11] Resource temporarily unavailable`). A hard recreate/pull restored service at that time.

After the later power outage, Byparr presented a more subtle failure:

- `/docs` returned `HTTP 200`;
- the FastAPI/Uvicorn application was running;
- Docker could eventually report the container as healthy;
- but the real `/health` endpoint returned `HTTP 502`;
- the response contained `NS_ERROR_UNKNOWN_HOST` while attempting to browse to Google;
- logs also showed DNS failures resolving `checkip.amazonaws.com`.

Prowlarr itself could still resolve public names, so the problem was isolated to Byparr's DNS path rather than the whole Docker host.

## Docker DNS configuration

Byparr now uses independent public DNS instead of the local AdGuard instance:

```yaml
  byparr:
    image: ghcr.io/thephaseless/byparr:latest
    restart: unless-stopped
    dns:
      - 1.1.1.1
      - 8.8.8.8
    environment:
      - TZ=America/Denver
    ports:
      - "8191:8191"
```

This is intentional. Byparr's browser/scraping traffic should not depend on AdGuard being ready on the same Docker host after a reboot or outage.

AdGuard still remains the main LAN DNS and provides the private `*.r515.allenfamhouse.com` rewrite. This Byparr exception is only for the container's own public DNS lookups.

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

## Functional health check

Use the real `/health` endpoint as the primary functional test:

```bash
curl -i --max-time 15 http://127.0.0.1:8191/health
```

Expected healthy response pattern:

```text
HTTP/1.1 200 OK
{"msg":"Byparr is working!","version":"3.0.4", ...}
```

Do **not** use `/docs` alone as proof that Byparr is healthy. `/docs` only confirms that the FastAPI web server is responding; Byparr can still have broken browser DNS/outbound access.

Confirm the container's DNS configuration:

```bash
cd /srv/docker
CID=$(sudo docker compose ps -q byparr)
sudo docker inspect "$CID" --format 'Byparr DNS={{json .HostConfig.Dns}}'
```

Expected:

```text
Byparr DNS=["1.1.1.1","8.8.8.8"]
```

Basic API-style test:

```bash
curl -i -X POST http://192.168.10.135:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd":"request.get","url":"https://example.com","maxTimeout":60000}' | head -80
```

If `/health` or the API-style test fails while `/docs` works, treat Byparr's browser/network layer as unhealthy.

## Automatic boot recovery v5

Byparr/Prowlarr recovery is handled by:

```text
Unit:   r515-byparr-recovery.service
Script: /usr/local/sbin/r515-byparr-recovery.sh
```

It runs after the main R515 post-boot/storage recovery service.

Final v5 behavior:

1. ensure Byparr is running;
2. call the real `/health` endpoint;
3. require the expected `Byparr is working!` payload;
4. if health fails, recreate Byparr at most once per boot;
5. use `/run/r515-byparr-recreated-this-boot` to prevent repeated recreate loops;
6. restart Prowlarr only after Byparr passes real health;
7. let systemd retry later if health still fails.

The service is expected to finish as:

```text
active (exited)
status=0/SUCCESS
```

A previous v4 implementation wrote the health response to `/tmp/byparr-real-health`. That caused `Permission denied` under the systemd execution context, falsely marked Byparr unhealthy, and triggered repeated recreates. v5 captures the health response in memory and no longer uses that `/tmp` file.

## Manual recovery procedure

Use this only when real `/health` fails or Prowlarr reports Byparr-related failures.

### 1. Check real health and logs

```bash
cd /srv/docker
sudo docker compose ps byparr prowlarr
curl -i --max-time 15 http://127.0.0.1:8191/health
sudo docker compose logs byparr --tail=120
```

DNS-related failure signs include:

```text
HTTP 502 from /health
NS_ERROR_UNKNOWN_HOST
Temporary failure in name resolution
checkip.amazonaws.com resolution failure
```

### 2. Confirm Byparr DNS

```bash
CID=$(sudo docker compose ps -q byparr)
sudo docker inspect "$CID" --format 'Byparr DNS={{json .HostConfig.Dns}}'
```

Expected:

```text
["1.1.1.1","8.8.8.8"]
```

### 3. Recreate Byparr if necessary

```bash
cd /srv/docker
sudo docker compose up -d --no-deps --force-recreate byparr
```

Do not pull a new image on every boot. If a normal recreate does not recover the service and an image issue is suspected, pull manually:

```bash
sudo docker compose pull byparr
sudo docker compose up -d --no-deps --force-recreate byparr
```

### 4. Verify and restart Prowlarr

```bash
curl -i --max-time 15 http://127.0.0.1:8191/health
sudo docker compose restart prowlarr
```

Then in Prowlarr:

```text
Indexers -> Test All
```

If Byparr passes but only certain indexers fail, treat those indexers as the likely problem rather than recreating Byparr repeatedly.

## Monitoring

Recommended Uptime Kuma monitor:

```text
Name: Byparr
Type: HTTP(s)
URL: http://192.168.10.135:8191/health
```

The monitor should use `/health`, not `/docs`.

## Backup

After material configuration changes, include `/srv/docker` in the normal R515 configuration backup workflow:

```bash
cd /srv/docker
/srv/docker/scripts/backup-r515-configs.sh after-byparr-change
```
