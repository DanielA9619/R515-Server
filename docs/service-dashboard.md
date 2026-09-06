# Service Dashboard / Central Portal

This document tracks the two internal landing pages for the R515 home server.

## Current design

Use two launchers instead of forcing one dashboard to fit every screen:

```text
Desktop -> Homarr
Mobile  -> Quick Links
```

Homarr is the richer visual dashboard. Quick Links is the preferred phone launcher because it is deliberately simple, fast, and easy to tap while connected to the home LAN or UniFi Teleport.

## Preferred URLs

```text
Quick Links: https://links.r515.allenfamhouse.com
Homarr:      https://homarr.r515.allenfamhouse.com
```

The older/base Homarr name still works:

```text
https://r515.allenfamhouse.com
```

Direct fallbacks:

```text
Quick Links: http://192.168.10.135:8070
Homarr:      http://192.168.10.135:7575
```

## Quick Links

Quick Links runs in the standalone `quicklinks` nginx container and currently presents 12 cards:

- Seerr
- Radarr
- Sonarr
- qBittorrent
- Uptime Kuma
- Jellyfin
- Prowlarr
- Portainer
- AdGuard Home
- Proxmox
- Home Assistant
- Homarr

All cards now point to clean `*.r515.allenfamhouse.com` internal HTTPS names rather than raw IP/port URLs.

Home Assistant is the only card whose clean route is not fully usable yet; Caddy routing exists, but HA still needs its trusted-proxy configuration.

## Homarr

Homarr remains the preferred desktop dashboard and continues to provide richer service cards and status views.

Preferred name:

```text
https://homarr.r515.allenfamhouse.com
```

Legacy/base internal name:

```text
https://r515.allenfamhouse.com
```

## Internal DNS and Caddy

AdGuard provides:

```text
*.r515.allenfamhouse.com -> 192.168.10.135
r515.allenfamhouse.com   -> 192.168.10.135
```

Caddy terminates internal HTTPS and reverse proxies each service. Every private R515 site imports the `private_only` matcher so the names remain usable from the LAN and UniFi Teleport but are not intended as public endpoints.

See [`docs/domains.md`](domains.md) for the full domain map and Caddy safety model.

## Home Assistant launcher integration

Do not duplicate every R515 service as a separate Home Assistant dashboard button. The cleaner pattern is one large R515 button opening:

```text
https://links.r515.allenfamhouse.com
```

Quick Links then acts as the single mobile launcher.

## Uptime Kuma

Preferred Uptime Kuma app URL:

```text
https://uptime.r515.allenfamhouse.com
```

Direct status page fallback remains:

```text
http://192.168.10.135:3001/status/r515
```

A normal card/link is preferred over iframe embedding because it is simpler and avoids unnecessary clickjacking/iframe configuration.

## Internal TLS

The private R515 hostnames use Caddy `tls internal`. Client devices should trust Caddy's internal root CA to avoid browser warnings.

## Safety rules

- UniFi Teleport is the current private remote-access path.
- Keep Quick Links, Homarr, qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Proxmox, and Home Assistant LAN/Teleport-only.
- Do not expose Quick Links port `8070` or the admin service ports through router forwarding.
- Keep all passwords, API keys, VPN keys, DuckDNS tokens, Mullvad keys, and private keys out of GitHub.

## Remaining work

1. Finish Home Assistant trusted-proxy configuration for `https://ha.r515.allenfamhouse.com`.
2. Add `https://links.r515.allenfamhouse.com` to the iPhone Home Screen.
3. Add one large R515 button in Home Assistant pointing to Quick Links.
4. Optionally move Quick Links into the main Compose stack later.
