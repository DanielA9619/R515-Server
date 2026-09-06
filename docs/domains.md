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

## Future remote-access thought

It is technically possible to add more public hostnames, either through additional DuckDNS names or through another DNS/domain setup pointing at Caddy.

However, the current policy is:

- Keep only Jellyfin public for now.
- Use UniFi Teleport for private remote access to internal services.
- Do not expose admin services or Quick Links directly through DuckDNS/Caddy.
- If remote access is needed for additional tools, design it intentionally first.

Possible future approaches:

| Approach | Best use | Notes |
| --- | --- | --- |
| Extra DuckDNS hostname + Caddy | Public user-facing app, if intentionally approved | Could work for something like a protected request page, but not for raw admin dashboards. |
| VPN / UniFi Teleport / WireGuard / Tailscale-style access | Admin apps and private dashboards | Preferred direction for Proxmox, Portainer, qBittorrent, Radarr, Sonarr, AdGuard, Homarr, Home Assistant, and Quick Links. |
| Access-protected tunnel / proxy | Public-ish access with an extra identity layer | Only after auth, headers, logging, and service-specific risks are understood. |
| Internal-only aliases | Clean LAN URLs | Current safest direction for most services. |

Candidate public-service ideas to revisit later:

```text
requests.<future-domain-or-duckdns> -> Seerr or SMS/request frontend, only with strong auth
status.<future-domain-or-duckdns>   -> limited status page, not the full Uptime Kuma admin app
```

Services that should remain LAN/VPN-only unless remote access is redesigned with strong protection:

```text
qBittorrent
Prowlarr
Radarr
Sonarr
Byparr
Seerr
Portainer
Uptime Kuma
AdGuard Home
Homarr
Proxmox
Home Assistant
Quick Links
SMS bot webhook/admin functions
```

## Current internal DNS / local domain

| Name | Purpose | Current state |
| --- | --- | --- |
| `https://r515.allenfamhouse.com` | Main Homarr desktop dashboard / central portal | Active internal hostname. AdGuard DNS rewrite points it to `192.168.10.135`; Caddy reverse proxies it to `homarr:7575` using Caddy internal TLS. |
| `http://r515.allenfamhouse.com:7575` | Direct Homarr access through local DNS with explicit port | Works without Caddy reverse proxy, but the preferred desktop URL is `https://r515.allenfamhouse.com`. |
| `http://192.168.10.135:8070` | Quick Links mobile launcher | Active direct LAN/UniFi Teleport URL. No public exposure. |

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
| Quick Links | `http://192.168.10.135:8070` | LAN / UniFi Teleport only |
| Homarr | `https://r515.allenfamhouse.com` | LAN/VPN-only |
| Homarr direct | `http://192.168.10.135:7575` | LAN/VPN-only |
| Jellyfin public | `https://mediahubdaniel.duckdns.org` | Public through Caddy only |
| Jellyfin local | `http://192.168.10.135:8096` | LAN-only |
| Seerr | `http://192.168.10.135:5055` | LAN/VPN-only |
| Uptime Kuma | `http://192.168.10.135:3001` | LAN/VPN-only |
| Uptime Kuma status page | `http://192.168.10.135:3001/status/r515` | LAN/VPN-only |
| AdGuard Home | `http://192.168.10.135:3002` | LAN/VPN-only |
| qBittorrent | `http://192.168.10.135:8080` | LAN/VPN-only, routed through Gluetun/Mullvad |
| Prowlarr | `http://192.168.10.135:9696` | LAN/VPN-only |
| Radarr | `http://192.168.10.135:7878` | LAN/VPN-only |
| Sonarr | `http://192.168.10.135:8989` | LAN/VPN-only |
| Byparr | `http://192.168.10.135:8191` | LAN/VPN-only helper service |
| Portainer | `https://192.168.10.135:9443` | LAN/VPN-only |
| Home Assistant VM | `http://192.168.10.127:8123` | LAN/VPN-only for now |
| Proxmox | `https://192.168.10.50:8006` | LAN/VPN-only |
| Samba share | `\\192.168.10.135\media` | LAN-only SMB |

## Planned / optional future internal aliases

These are not active unless explicitly created in AdGuard and/or Caddy later.

| Proposed name | Intended target | Notes |
| --- | --- | --- |
| `links.allenfamhouse.com` | Quick Links on port `8070` | Preferred future clean mobile URL. Keep LAN-only / Teleport-only; do not publish it publicly. |
| `requests.allenfamhouse.com` | Seerr on port `5055` | Good future clean URL for movie/TV requests. Keep LAN-only unless remote access is redesigned. |
| `status.allenfamhouse.com` | Uptime Kuma status page or Uptime Kuma app | Could point to `/status/r515` through Caddy later. Keep private unless intentionally redesigned. |
| `adguard.allenfamhouse.com` | AdGuard Home on port `3002` | Admin dashboard; keep LAN-only. |
| `portainer.allenfamhouse.com` | Portainer on port `9443` | Sensitive admin dashboard; do not expose publicly. |
| `proxmox.allenfamhouse.com` | Proxmox on port `8006` | Sensitive admin dashboard; do not expose publicly. |
| `ha.allenfamhouse.com` | Home Assistant VM on port `8123` | Only after the Home Assistant migration is stable; keep private unless remote access is intentionally redesigned. |

## Recommended naming direction

Short term:

```text
r515.allenfamhouse.com -> Homarr desktop dashboard
192.168.10.135:8070   -> Quick Links mobile launcher
```

Medium term:

```text
links.allenfamhouse.com    -> Quick Links
requests.allenfamhouse.com -> Seerr
status.allenfamhouse.com   -> Uptime Kuma status page
```

Keep the dashboard, launcher, request tools, and admin tools LAN/VPN-only unless remote access is intentionally redesigned with proper protection. UniFi Teleport already provides private remote access without making these services public.

## Safety rules

- Do not put DuckDNS tokens, API keys, passwords, VPN keys, Mullvad keys, or private keys in GitHub.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, and Quick Links LAN/VPN-only unless remote access is intentionally redesigned.
- Do not expose Quick Links port `8070` through public router forwarding, DuckDNS, or a public Caddy route.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep the central dashboard and mobile launcher internal unless remote access is redesigned with proper protection.
- Keep an AdGuard DNS rollback plan ready in case local DNS changes break client access.
