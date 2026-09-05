# Media Request Workflow

This document tracks how to make adding movies and TV to the server faster and less annoying.

## Problem

The current manual path is too slow:

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
Open one dashboard or app
Search title
Request/add title
Server searches automatically
Download/import happens in the background
Check one status place only when needed
```

The fallback advanced path should still exist, but only for weird cases.

## URL / access cleanup

Do not use GitHub as the daily URL launcher. GitHub should be the documentation fallback.

Current quick-access sources:

- README Quick Access URLs
- Homarr dashboard: `https://r515.allenfamhouse.com`
- Direct Homarr: `http://192.168.10.135:7575`
- UniFi Teleport for remote private access

Recommended next cleanup:

1. Make Homarr the real daily landing page.
2. Add or verify cards for:
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
3. Put the most-used cards at the top:
   - Seerr
   - Radarr
   - Sonarr
   - qBittorrent
   - Uptime Kuma
4. Add the Homarr URL as a browser bookmark and phone home-screen shortcut.
5. Later create clean internal aliases if useful:
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
Seerr -> request movie -> Radarr auto-searches -> qBittorrent downloads -> Radarr imports -> Jellyfin sees it
```

If Seerr does not find a good result or the request stalls:

```text
Radarr -> Movie -> Search / Interactive Search -> choose a release -> qBittorrent -> verify active download
```

Prowlarr should mostly be used for indexer management, not as the normal movie-search UI.

### TV

Preferred normal path:

```text
Seerr -> request series or season -> Sonarr auto-searches -> qBittorrent downloads -> Sonarr imports -> Jellyfin sees it
```

Fallback path:

```text
Sonarr -> Series -> Season/Episode -> Search / Interactive Search -> choose a release -> qBittorrent -> verify active download
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
Homarr = launchpad
Seerr = simple request UI
Radarr/Sonarr = advanced interactive search
qBittorrent = download status only
Uptime Kuma = is the stack healthy?
```

Daily use should start from Homarr, not GitHub.

## Possible improvements

### Internal clean URLs

Create LAN-only AdGuard/Caddy aliases so URLs are memorable:

```text
requests.allenfamhouse.com
radarr.allenfamhouse.com
sonarr.allenfamhouse.com
downloads.allenfamhouse.com
status.allenfamhouse.com
```

These should remain internal/VPN-only.

### Dashboard status links

Add direct cards/buttons in Homarr:

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

- Keep admin apps LAN/VPN-only.
- Do not expose Prowlarr, Radarr, Sonarr, qBittorrent, Byparr, Portainer, AdGuard, Proxmox, Home Assistant, or Homarr directly to the public internet.
- Keep qBittorrent behind Gluetun/Mullvad.
- Use legal/owned media sources and indexers appropriate for the user's rights and local laws.
- Do not depend on fragile challenge-solving helpers for normal day-to-day searches if stable direct indexers are available.
