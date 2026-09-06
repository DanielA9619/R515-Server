# Media Request Workflow

This document tracks the preferred way to request and manage movies/TV on the R515 without looking up raw IPs and ports.

## Normal mobile flow

```text
UniFi Teleport -> https://links.r515.allenfamhouse.com -> Seerr / Radarr / Sonarr / qBittorrent / Uptime Kuma
```

Quick Links is the normal phone launchpad. Homarr remains the richer desktop dashboard.

```text
Mobile  -> https://links.r515.allenfamhouse.com
Desktop -> https://homarr.r515.allenfamhouse.com
```

Both are private LAN / UniFi Teleport services.

## Preferred service URLs

```text
Seerr        https://seerr.r515.allenfamhouse.com
Radarr       https://radarr.r515.allenfamhouse.com
Sonarr       https://sonarr.r515.allenfamhouse.com
qBittorrent  https://qbittorrent.r515.allenfamhouse.com
Uptime Kuma  https://uptime.r515.allenfamhouse.com
Prowlarr     https://prowlarr.r515.allenfamhouse.com
Jellyfin LAN https://jellyfin.r515.allenfamhouse.com
Jellyfin WAN https://mediahubdaniel.duckdns.org
```

## Movies

Normal path:

```text
Quick Links -> Seerr -> request movie -> Radarr auto-searches -> qBittorrent downloads -> Radarr imports -> Jellyfin sees it
```

Fallback/advanced path:

```text
Quick Links -> Radarr -> Movie -> Search / Interactive Search -> choose release -> qBittorrent -> verify active download
```

Prowlarr is primarily for indexer management rather than the normal movie-search UI.

## TV

Normal path:

```text
Quick Links -> Seerr -> request series/season -> Sonarr auto-searches -> qBittorrent downloads -> Sonarr imports -> Jellyfin sees it
```

Fallback path:

```text
Quick Links -> Sonarr -> Series -> Season/Episode -> Search / Interactive Search -> choose release -> qBittorrent
```

## Reliability checklist

### Radarr / Sonarr

1. Root folders are correct:
   - Radarr: `/movies`
   - Sonarr: `/tv`
2. Download client is qBittorrent through host `gluetun`.
3. Categories are correct:
   - Radarr: `radarr`
   - Sonarr: `sonarr`
4. Quality profiles allow the intended 1080p/4K behavior.
5. Monitoring is enabled for requested media.
6. Search actually triggers after request/add.
7. Failed downloads are removed/researched if needed.

### Prowlarr

1. Indexers are healthy.
2. Categories are mapped correctly.
3. Indexer priority is sensible.
4. Minimum seeders are not overly restrictive.
5. Fragile/bad indexers are disabled.
6. Byparr is only used where needed.

### qBittorrent

1. Preferred Web UI: `https://qbittorrent.r515.allenfamhouse.com`.
2. Direct fallback: `http://192.168.10.135:8080`.
3. qBittorrent remains routed through Gluetun/Mullvad.
4. Network-interface binding remains on the VPN interface.
5. Categories match Radarr/Sonarr.
6. Save paths remain under `/mnt/storage/downloads`.

## One-screen goal

```text
Quick Links = mobile launchpad
Homarr = desktop dashboard
Seerr = normal request UI
Radarr/Sonarr = advanced interactive search
qBittorrent = download status
Prowlarr = indexer management
Uptime Kuma = service health
```

GitHub is documentation and recovery reference, not the daily URL launcher.

## Home Assistant shortcut

The preferred future Home Assistant dashboard pattern is one R515 button opening:

```text
https://links.r515.allenfamhouse.com
```

Do not duplicate all service links in Home Assistant.

## Safety notes

- UniFi Teleport is the current private remote-access path.
- All `*.r515.allenfamhouse.com` management/request names remain LAN/Teleport-only and are protected by Caddy's `private_only` gate.
- Do not expose Quick Links port `8070` or qBittorrent/admin ports directly to the internet.
- Keep qBittorrent behind Gluetun/Mullvad.
- Use legal/owned media sources and indexers appropriate for the user's rights and local laws.
- Do not commit passwords, API keys, tokens, DuckDNS tokens, Mullvad keys, or private keys.
