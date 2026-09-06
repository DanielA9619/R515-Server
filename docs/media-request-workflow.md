# Media Request Workflow

This document tracks how to make adding movies and TV to the server faster and less annoying.

## Problem

The old manual path is too slow:

```text
Connect through UniFi Teleport
Look up service URLs in GitHub
Open Prowlarr
Search for the title
Use interactive search
Pick a release
Open qBittorrent
Check whether it is downloading
Wait/check Jellyfin later
```

That path works for troubleshooting, but it should not be the normal user flow.

## Desired outcome

A normal movie or TV request should feel like this:

```text
Open one mobile launcher or dashboard
Search title
Request/add title
Server searches automatically
Download/import happens in the background
Check one status place only when needed
```

The fallback advanced path should still exist, but only for weird cases.

## Daily mobile flow

The preferred remote/private phone flow is:

```text
UniFi Teleport -> Quick Links -> Seerr / Radarr / Sonarr / qBittorrent / Uptime Kuma
```

Quick Links is available at:

```text
http://192.168.10.135:8070
```

Use Seerr for normal movie/TV requests, Radarr or Sonarr for advanced interactive searches, qBittorrent for download status, and Uptime Kuma for service health.

Quick Links is LAN / UniFi Teleport only. It is not intended to be exposed publicly.

## URL / access cleanup

Do not use GitHub as the daily URL launcher. GitHub should be the documentation fallback.

Current quick-access sources:

- Quick Links mobile launcher: `http://192.168.10.135:8070`
- Homarr desktop dashboard: `https://r515.allenfamhouse.com`
- Direct Homarr: `http://192.168.10.135:7575`
- README Quick Access URLs
- UniFi Teleport for remote private access

Current launcher roles:

```text
Mobile  -> Quick Links
Desktop -> Homarr
```

Recommended cleanup:

1. Use Quick Links as the daily mobile landing page.
2. Keep Homarr as the richer desktop dashboard.
3. Keep these services reachable from Quick Links:
   - Seerr
   - Radarr
   - Sonarr
   - Prowlarr
   - qBittorrent
   - Uptime Kuma
   - AdGuard Home
   - Portainer
   - Proxmox
   - Home Assistant
   - Jellyfin
   - Homarr
4. Put the most-used mobile links first:
   - Seerr
   - Radarr
   - Sonarr
   - qBittorrent
   - Uptime Kuma
5. Add Quick Links to the iPhone Home Screen.
6. Add one large R515 button in Home Assistant that opens `http://192.168.10.135:8070` instead of duplicating every server link.
7. Later create clean internal aliases if useful:
   - `links.allenfamhouse.com` -> Quick Links
   - `requests.allenfamhouse.com` -> Seerr
   - `radarr.allenfamhouse.com` -> Radarr
   - `sonarr.allenfamhouse.com` -> Sonarr
   - `downloads.allenfamhouse.com` -> qBittorrent
   - `status.allenfamhouse.com` -> Uptime Kuma status page

Keep all of these LAN/VPN-only unless remote access is intentionally redesigned.

## Recommended normal request flow

### Movies

Preferred normal path:

```text
Quick Links -> Seerr -> request movie -> Radarr auto-searches -> qBittorrent downloads -> Radarr imports -> Jellyfin sees it
```

If Seerr does not find a good result or the request stalls:

```text
Quick Links -> Radarr -> Movie -> Search / Interactive Search -> choose a release -> qBittorrent -> verify active download
```

Prowlarr should mostly be used for indexer management, not as the normal movie-search UI.

### TV

Preferred normal path:

```text
Quick Links -> Seerr -> request series or season -> Sonarr auto-searches -> qBittorrent downloads -> Sonarr imports -> Jellyfin sees it
```

Fallback path:

```text
Quick Links -> Sonarr -> Series -> Season/Episode -> Search / Interactive Search -> choose a release -> qBittorrent -> verify active download
```

## Better finding / reliability checklist

When results are bad or searches do not find good releases, tune the automation before blaming the UI.

### Radarr / Sonarr

Check:

1. Root folders are correct:
   - Radarr: `/movies`
   - Sonarr: `/tv`
2. Download client is qBittorrent through host `gluetun`.
3. Categories are correct:
   - Radarr: `radarr`
   - Sonarr: `sonarr`
4. Quality profiles match the desired behavior:
   - 1080p fallback allowed
   - 4K upgrades allowed only where wanted
   - sizes are not so strict that good results are rejected
5. Monitoring is enabled for the item/season/episodes being requested.
6. The search is actually being triggered after request/add.
7. Failed downloads are removed/researched if needed.

### Prowlarr

Check:

1. Indexers are healthy.
2. Indexer categories are mapped correctly for movies/TV.
3. Indexer priority is sensible.
4. Minimum seeders are not set too high.
5. Bad/fragile indexers are disabled instead of poisoning search results.
6. Byparr is only used where needed; do not route every indexer through it by default.

### qBittorrent

Check:

1. qBittorrent Web UI is reachable at `http://192.168.10.135:8080`.
2. qBittorrent is still routed through Gluetun/Mullvad.
3. Downloads are not stalled because of VPN/interface binding.
4. Categories match Radarr/Sonarr.
5. Save paths still point under `/mnt/storage/downloads`.

## One-screen workflow goal

Best practical setup:

```text
Quick Links = mobile launchpad
Homarr = desktop dashboard
Seerr = simple request UI
Radarr/Sonarr = advanced interactive search
qBittorrent = download status only
Uptime Kuma = is the stack healthy?
```

Daily mobile use should start from Quick Links, not GitHub. Desktop use can continue to start from Homarr.

## Possible improvements

### Internal clean URLs

Create LAN-only AdGuard/Caddy aliases so URLs are memorable:

```text
links.allenfamhouse.com
requests.allenfamhouse.com
radarr.allenfamhouse.com
sonarr.allenfamhouse.com
downloads.allenfamhouse.com
status.allenfamhouse.com
```

These should remain internal/VPN-only.

### Dashboard status links

Keep direct cards/buttons available in Homarr and Quick Links:

```text
Request Movie/TV -> Seerr
Movies Advanced -> Radarr
TV Advanced -> Sonarr
Downloads -> qBittorrent
Search/Indexers -> Prowlarr
Health -> Uptime Kuma status page
```

### Better notifications

Later, add notifications for:

```text
Request approved
Download started
Download failed
Import completed
Available in Jellyfin
```

Potential destinations:

```text
Discord
Pushover
Email
Home Assistant notification
SMS bot later, if resumed
```

### Request bot later

The local SMS bot already proves a very fast text-command style flow is possible, but SMS/Twilio is intentionally paused. A future bot could become the fastest flow:

```text
Movie Interstellar
TV Silo season 2
Status
Downloads
Recently added
```

Do not resume SMS/provider work until intentionally approved.

## Safety notes

- UniFi Teleport is the current private remote-access path for the daily mobile workflow.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, and Quick Links LAN/VPN-only unless remote access is intentionally redesigned.
- Do not expose Quick Links port `8070` directly to the public internet.
- Keep qBittorrent behind Gluetun/Mullvad.
- Use legal/owned media sources and indexers appropriate for the user's rights and local laws.
- Do not depend on fragile challenge-solving helpers for normal day-to-day searches if stable direct indexers are available.
- Do not commit passwords, API keys, tokens, DuckDNS tokens, Mullvad keys, or private keys to GitHub.
