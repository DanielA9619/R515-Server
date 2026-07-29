# Service Domains and Local URLs

This document tracks the known public domains, internal DNS names, local service URLs, and planned aliases for the R515 home server.

## Current public domain

| Name | Purpose | Destination / notes |
| --- | --- | --- |
| `https://mediahubdaniel.duckdns.org` | Public Jellyfin access | Public DNS points to the home WAN IP, UniFi forwards ports `80` and `443` to Caddy on `docker01`, and Caddy reverse proxies to `jellyfin:8096`. |

Safety notes:

- Do not expose Jellyfin port `8096` directly to the internet.
- Public Jellyfin access should go through Caddy on ports `80` and `443` only.
- Keep the DuckDNS token out of GitHub.

## Current internal DNS / local domain

| Name | Purpose | Current state |
| --- | --- | --- |
| `https://r515.allenfamhouse.com` | Main Homarr dashboard / central portal | Active internal hostname. AdGuard DNS rewrite points it to `192.168.10.135`; Caddy reverse proxies it to `homarr:7575` using Caddy internal TLS. |
| `http://r515.allenfamhouse.com:7575` | Direct Homarr access through local DNS with explicit port | Works without Caddy reverse proxy, but the preferred URL is `https://r515.allenfamhouse.com`. |

Current AdGuard DNS rewrite:

```text
r515.allenfamhouse.com -> 192.168.10.135
```

Current Caddy route:

```caddyfile
r515.allenfamhouse.com {
    tls internal
    reverse_proxy homarr:7575
}
```

Important note: `https://r515.allenfamhouse.com` uses Caddy's internal CA, so browsers show a certificate warning unless the Caddy internal root certificate is trusted on the client device.

## Current service URLs

| Service | Preferred URL / current URL | Exposure |
| --- | --- | --- |
| Homarr | `https://r515.allenfamhouse.com` | LAN-only |
| Homarr direct | `http://192.168.10.135:7575` | LAN-only |
| Jellyfin public | `https://mediahubdaniel.duckdns.org` | Public through Caddy only |
| Jellyfin local | `http://192.168.10.135:8096` | LAN-only |
| Seerr | `http://192.168.10.135:5055` | LAN-only |
| Uptime Kuma | `http://192.168.10.135:3001` | LAN-only |
| Uptime Kuma status page | `http://192.168.10.135:3001/status/r515` | LAN-only |
| AdGuard Home | `http://192.168.10.135:3002` | LAN-only |
| qBittorrent | `http://192.168.10.135:8080` | LAN-only, routed through Gluetun/Mullvad |
| Prowlarr | `http://192.168.10.135:9696` | LAN-only |
| Radarr | `http://192.168.10.135:7878` | LAN-only |
| Sonarr | `http://192.168.10.135:8989` | LAN-only |
| Byparr | `http://192.168.10.135:8191` | LAN-only helper service |
| Portainer | `https://192.168.10.135:9443` | LAN-only |
| Home Assistant VM | `http://192.168.10.127:8123` | LAN-only for now |
| Proxmox | `https://192.168.10.50:8006` | LAN-only |
| Samba share | `\\192.168.10.135\media` | LAN-only SMB |

## Planned / optional future internal aliases

These are not active unless explicitly created in AdGuard and/or Caddy later.

| Proposed name | Intended target | Notes |
| --- | --- | --- |
| `requests.allenfamhouse.com` | Seerr on port `5055` | Good future clean URL for movie/TV requests. Keep LAN-only unless remote access is redesigned. |
| `status.allenfamhouse.com` | Uptime Kuma status page or Uptime Kuma app | Could point to `/status/r515` through Caddy later. |
| `adguard.allenfamhouse.com` | AdGuard Home on port `3002` | Admin dashboard; keep LAN-only. |
| `portainer.allenfamhouse.com` | Portainer on port `9443` | Sensitive admin dashboard; do not expose publicly. |
| `proxmox.allenfamhouse.com` | Proxmox on port `8006` | Sensitive admin dashboard; do not expose publicly. |
| `ha.allenfamhouse.com` | Home Assistant VM on port `8123` | Only after the Home Assistant migration is stable. |

## Recommended naming direction

Short term:

```text
r515.allenfamhouse.com -> Homarr central dashboard
```

Medium term:

```text
requests.allenfamhouse.com -> Seerr
status.allenfamhouse.com   -> Uptime Kuma status page
```

Keep the dashboard and admin tools LAN-only unless remote access is intentionally redesigned with proper protection such as VPN, Tailscale, WireGuard, Cloudflare Access-style protection, or another deliberate access-control layer.

## Safety rules

- Do not put DuckDNS tokens, API keys, passwords, VPN keys, or private keys in GitHub.
- Do not expose qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, or Home Assistant directly to the public internet.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep the central dashboard internal unless remote access is redesigned with proper protection.
- Keep an AdGuard DNS rollback plan ready in case local DNS changes break client access.
