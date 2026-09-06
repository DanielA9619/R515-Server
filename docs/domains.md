# Service Domains and Local URLs

This document tracks the public and private service names used by the R515 home server.

## Public service

Only Jellyfin is intentionally public:

| Name | Purpose | Notes |
| --- | --- | --- |
| `https://mediahubdaniel.duckdns.org` | Public Jellyfin | UniFi forwards ports `80` and `443` to Caddy on `docker01`; Caddy reverse proxies to `jellyfin:8096`. |

Do not expose Jellyfin port `8096` directly and do not publish the private R515 service names below.

## Private internal DNS

AdGuard Home provides the internal wildcard rewrite:

```text
*.r515.allenfamhouse.com -> 192.168.10.135
r515.allenfamhouse.com   -> 192.168.10.135
```

The wildcard is for LAN and UniFi Teleport clients using AdGuard DNS. Public resolvers do not provide these private service records.

## Active internal URLs

| Service | Preferred URL | Direct fallback / backend | Exposure |
| --- | --- | --- | --- |
| Quick Links | `https://links.r515.allenfamhouse.com` | `http://192.168.10.135:8070` | LAN / Teleport only |
| Homarr | `https://homarr.r515.allenfamhouse.com` | `http://192.168.10.135:7575` | LAN / Teleport only |
| Homarr legacy/base name | `https://r515.allenfamhouse.com` | `http://192.168.10.135:7575` | LAN / Teleport only |
| Seerr | `https://seerr.r515.allenfamhouse.com` | `http://192.168.10.135:5055` | LAN / Teleport only |
| Radarr | `https://radarr.r515.allenfamhouse.com` | `http://192.168.10.135:7878` | LAN / Teleport only |
| Sonarr | `https://sonarr.r515.allenfamhouse.com` | `http://192.168.10.135:8989` | LAN / Teleport only |
| qBittorrent | `https://qbittorrent.r515.allenfamhouse.com` | `http://192.168.10.135:8080` | LAN / Teleport only; qBittorrent remains behind Gluetun/Mullvad |
| Uptime Kuma | `https://uptime.r515.allenfamhouse.com` | `http://192.168.10.135:3001` | LAN / Teleport only |
| Prowlarr | `https://prowlarr.r515.allenfamhouse.com` | `http://192.168.10.135:9696` | LAN / Teleport only |
| Portainer | `https://portainer.r515.allenfamhouse.com` | `https://192.168.10.135:9443` | LAN / Teleport only |
| AdGuard Home | `https://adguard.r515.allenfamhouse.com` | `http://192.168.10.135:3002` | LAN / Teleport only |
| Proxmox | `https://proxmox.r515.allenfamhouse.com` | `https://192.168.10.50:8006` | LAN / Teleport only |
| Home Assistant | `https://ha.r515.allenfamhouse.com` | `http://192.168.10.127:8123` | LAN / Teleport only; Caddy route active, HA trusted-proxy setting still pending |
| Jellyfin internal | `https://jellyfin.r515.allenfamhouse.com` | `http://192.168.10.135:8096` | LAN / Teleport only |
| Jellyfin public | `https://mediahubdaniel.duckdns.org` | `jellyfin:8096` through Caddy | Public |

Other direct LAN-only services that do not currently have dedicated clean aliases:

```text
Byparr:  http://192.168.10.135:8191
SMS bot: http://192.168.10.135:5070/health
Samba:   \\192.168.10.135\media
```

## Caddy private-only gate

Because WAN ports `80` and `443` are forwarded to Caddy for public Jellyfin, private DNS alone is not considered an access-control boundary. Every private R515 Caddy site imports an explicit private-network matcher:

```caddyfile
(private_only) {
    @denied not remote_ip private_ranges
    abort @denied
}
```

Example private site:

```caddyfile
links.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy quicklinks:80
}
```

The public Jellyfin block at `mediahubdaniel.duckdns.org` does **not** import `private_only`.

This design means the clean internal hostnames work from the home LAN and UniFi Teleport while remaining unavailable as normal public service endpoints.

## Internal TLS

The `*.r515.allenfamhouse.com` sites use Caddy `tls internal` certificates. Client devices must trust Caddy's internal root CA to avoid browser certificate warnings.

Portainer and Proxmox use HTTPS on their backends. Caddy currently connects to those trusted-LAN backends with certificate verification disabled at the upstream hop while still providing Caddy internal TLS to the client.

## Home Assistant note

The Caddy route for `ha.r515.allenfamhouse.com` is active, but Home Assistant currently responds with HTTP `400` until its reverse-proxy trust is configured.

On Home Assistant 2026.8+, go to:

```text
Settings -> System -> Network -> HTTP server
```

Turn on **Trust X-Forwarded-For** and add the Caddy proxy IP to **Trusted proxies**. The expected source in this setup is `192.168.10.135`. Saving the HTTP server settings restarts Home Assistant and requires confirmation after restart.

If the route still returns `400`, use the exact rejected proxy source shown in the Home Assistant log instead of trusting a broad network.

## Current verification checkpoint

The following private routes were tested successfully through Caddy on September 6, 2026:

```text
Quick Links   200
Seerr         307
Radarr        302
Sonarr        302
qBittorrent   200
Uptime Kuma   302
Prowlarr      302
Portainer     200
AdGuard       302
Proxmox       200
Homarr        200
Jellyfin LAN  302
```

Public Jellyfin also returned `302`, confirming the public route remained available after the internal-domain work.

Home Assistant returned `400`, which is expected until its trusted-proxy setting is added.

The Caddy host file and mounted container file hashes were confirmed identical after recreating the Caddy container, fixing an earlier stale single-file bind-mount inode problem.

## Safety rules

- Never commit DuckDNS tokens, API keys, passwords, VPN keys, Mullvad keys, private keys, or other secrets.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, Quick Links, and the internal Jellyfin alias LAN/Teleport-only.
- Keep qBittorrent behind Gluetun/Mullvad.
- Do not treat DNS secrecy as an access-control layer; keep the Caddy `private_only` gate on every private `r515` site.
- If another reverse proxy is introduced in front of Caddy later, revisit the `remote_ip` assumptions.
- Keep an AdGuard DNS rollback plan available.
