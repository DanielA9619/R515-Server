# Quick Links Mobile Launcher

Quick Links is the lightweight mobile-friendly launcher for the R515 home server. Homarr remains the richer desktop dashboard, while Quick Links is optimized for phone use over the home LAN or UniFi Teleport.

## Preferred URL

```text
https://links.r515.allenfamhouse.com
```

Direct fallback:

```text
http://192.168.10.135:8070
```

The preferred hostname is provided by the AdGuard wildcard rewrite for `*.r515.allenfamhouse.com` and Caddy reverse proxies it to `quicklinks:80` with Caddy internal TLS.

## Current page

The current launcher is a polished responsive page with:

- mobile-first layout
- 2 columns on small screens and 3 columns on wider screens
- dark/light mode through `prefers-color-scheme`
- header identifying the Dell PowerEdge R515
- LAN / Teleport private-access indicator
- Daily and Manage sections
- 12 service cards

Current cards:

| Service | URL |
| --- | --- |
| Seerr | `https://seerr.r515.allenfamhouse.com` |
| Radarr | `https://radarr.r515.allenfamhouse.com` |
| Sonarr | `https://sonarr.r515.allenfamhouse.com` |
| qBittorrent | `https://qbittorrent.r515.allenfamhouse.com` |
| Uptime Kuma | `https://uptime.r515.allenfamhouse.com` |
| Jellyfin | `https://jellyfin.r515.allenfamhouse.com` |
| Prowlarr | `https://prowlarr.r515.allenfamhouse.com` |
| Portainer | `https://portainer.r515.allenfamhouse.com` |
| AdGuard Home | `https://adguard.r515.allenfamhouse.com` |
| Proxmox | `https://proxmox.r515.allenfamhouse.com` |
| Home Assistant | `https://ha.r515.allenfamhouse.com` |
| Homarr | `https://homarr.r515.allenfamhouse.com` |

Home Assistant's card is already pointed at its clean hostname, but HA itself still needs its trusted reverse-proxy setting before that route will stop returning HTTP `400`.

## Container

| Item | Value |
| --- | --- |
| Container name | `quicklinks` |
| Image | `nginx:alpine` |
| Host port | `8070` |
| Container port | `80` |
| Local content path | `/srv/docker/quicklinks/index.html` |
| Mounted directory | `/srv/docker/quicklinks` -> `/usr/share/nginx/html:ro` |

Current standalone Docker run command:

```bash
sudo docker run -d --name quicklinks --restart unless-stopped -p 8070:80 -v /srv/docker/quicklinks:/usr/share/nginx/html:ro nginx:alpine
```

The content is directory-mounted, so edits to `/srv/docker/quicklinks/index.html` appear in nginx without recreating the container.

## Caddy route

```caddyfile
links.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy quicklinks:80
}
```

Quick Links is intentionally protected by the same `private_only` Caddy gate as the other internal services.

## Tests

Direct nginx test:

```bash
curl -I http://192.168.10.135:8070
```

Preferred HTTPS test:

```bash
curl -k -I https://links.r515.allenfamhouse.com
```

Container test:

```bash
sudo docker ps --filter name=quicklinks
```

Verified result on September 6, 2026: preferred HTTPS returned HTTP `200`.

## Safety notes

- Quick Links is for LAN / UniFi Teleport access only.
- Do not expose port `8070` directly through router forwarding.
- The page is a launcher, not an authentication boundary.
- Every linked admin/media-management service remains private unless intentionally redesigned.
- Do not put passwords, API keys, tokens, DuckDNS tokens, Mullvad keys, private keys, or other secrets into the page or repository.
- The internal hostname uses Caddy `tls internal`; trust the Caddy internal CA on client devices if certificate warnings are undesirable.

## Remaining improvements

1. Fold Quick Links into the main `docker-compose.yml` or an override file so lifecycle management matches the rest of the stack.
2. Add `https://links.r515.allenfamhouse.com` to the iPhone Home Screen for one-tap access.
3. Add one large R515 button to Home Assistant that opens `https://links.r515.allenfamhouse.com`.
4. Finish Home Assistant trusted-proxy configuration so its Quick Links card works through `https://ha.r515.allenfamhouse.com`.
