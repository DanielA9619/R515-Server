# Service Dashboard / Central Portal

This document tracks the central landing pages for the R515 home server services.

## Goal

Provide simple internal launchers for local services so the user does not need to remember every IP address and port.

The current split is:

- Homarr remains useful as the richer desktop dashboard.
- Quick Links is the preferred mobile launcher because Homarr's icons/text are too cramped on a phone.

## Current status

Homarr is installed in Docker on `docker01` and is reachable on the LAN at:

```text
http://192.168.10.135:7575
```

The user completed Homarr setup and added cards for the main services.

The Uptime Kuma status page has also been added as a prominent card/link in Homarr:

```text
R515 Server Status -> http://192.168.10.135:3001/status/r515
```

Home Assistant has been added to Homarr as an integration/card:

```text
Home Assistant VM -> http://192.168.10.127:8123
```

The internal AdGuard DNS rewrite for the preferred Homarr dashboard name is working:

```text
r515.allenfamhouse.com -> 192.168.10.135
```

Current Homarr access works directly with the Homarr port:

```text
http://r515.allenfamhouse.com:7575
```

Caddy has also been configured to reverse proxy Homarr over HTTPS using Caddy's internal CA:

```text
https://r515.allenfamhouse.com -> homarr:7575
```

This loads, but browsers show a certificate warning / "Not secure" because the certificate is issued by Caddy's local internal CA instead of a publicly trusted CA.

Quick Links is running as a lightweight standalone Docker container on `docker01` and is reachable at:

```text
http://192.168.10.135:8070
```

Quick Links is the preferred phone/mobile launcher. It is intentionally simple and should be reached only from the LAN or through UniFi Teleport.

Known dashboard/launcher links:

```text
Quick Links mobile   http://192.168.10.135:8070
Homarr portal        https://r515.allenfamhouse.com
Jellyfin             https://mediahubdaniel.duckdns.org
Seerr requests       http://192.168.10.135:5055
R515 status page     http://192.168.10.135:3001/status/r515
Portainer            https://192.168.10.135:9443
Uptime Kuma          http://192.168.10.135:3001
AdGuard Home         http://192.168.10.135:3002
qBittorrent          http://192.168.10.135:8080
Prowlarr             http://192.168.10.135:9696
Radarr               http://192.168.10.135:7878
Sonarr               http://192.168.10.135:8989
Byparr               http://192.168.10.135:8191
Home Assistant VM    http://192.168.10.127:8123
Proxmox              https://192.168.10.50:8006
```

The full domain/local URL map is tracked in [`docs/domains.md`](domains.md). Quick Links itself is documented in [`docs/quicklinks.md`](quicklinks.md).

## Preferred approach

Use two internal-only launchers rather than forcing one UI to work equally well everywhere:

```text
Desktop -> Homarr
Mobile  -> Quick Links
```

Homarr remains useful for desktop because it provides the richer visual dashboard and service cards. Quick Links is preferred on mobile because the lightweight page keeps links readable and easy to tap.

Both should remain private. UniFi Teleport is the current remote/private-access path; neither dashboard should be made public-facing.

Other options to consider later:

```text
Homepage
Dashy
```

## Home Assistant launcher integration

Home Assistant does not need to duplicate every R515 service link.

A cleaner mobile/dashboard pattern is one large R515 button that opens:

```text
http://192.168.10.135:8070
```

From there, Quick Links provides access to Seerr, Radarr, Sonarr, qBittorrent, Jellyfin, Uptime Kuma, Prowlarr, AdGuard Home, Portainer, Proxmox, Home Assistant, and Homarr.

This keeps the Home Assistant dashboard simple while preserving Quick Links as the single mobile launcher.

## Uptime Kuma status integration

Yes, include server status in the central portal.

Current status page:

```text
http://192.168.10.135:3001/status/r515
```

Current first version:

1. Add the Uptime Kuma status page as a prominent card/link in Homarr. Done.
2. Keep the status page LAN-only at first.
3. Keep Uptime Kuma available from Quick Links for mobile access.
4. Later optionally create a cleaner internal DNS name for it.

Later nice internal DNS names:

```text
r515.allenfamhouse.com      -> Homarr / desktop portal
links.allenfamhouse.com     -> Quick Links / mobile launcher
requests.allenfamhouse.com  -> Seerr requests
status.allenfamhouse.com    -> Uptime Kuma status page or Uptime Kuma instance
```

Embedding the Uptime Kuma status page inside the dashboard with an iframe is possible later, but not the first choice. Uptime Kuma requires a special iframe-related setting for embedding, and that has clickjacking/security tradeoffs. A normal card/link is safer and simpler.

## Domain plan

The user has a domain for the house, but a public-facing setup is not needed for either launcher.

Preferred local Homarr name:

```text
r515.allenfamhouse.com
```

Possible future LAN-only Quick Links alias:

```text
links.allenfamhouse.com
```

Current Homarr state:

1. Homarr is running on `192.168.10.135:7575`.
2. AdGuard DNS rewrite is working for `r515.allenfamhouse.com` -> `192.168.10.135`.
3. Direct access works with port `7575`:

```text
http://r515.allenfamhouse.com:7575
```

4. Caddy reverse proxy works without port `7575`:

```text
https://r515.allenfamhouse.com
```

5. The current HTTPS certificate is local/internal and therefore shows a browser warning unless the Caddy internal CA root certificate is trusted on the client device.

Quick Links currently uses direct LAN access on port `8070`; the future `links.allenfamhouse.com` alias should remain LAN-only if added.

HTTPS options for internal aliases:

1. Local/internal HTTPS using Caddy's internal CA. This can work LAN-only, but client devices need to trust the Caddy local root certificate or they will show certificate warnings.
2. Publicly trusted HTTPS using an ACME DNS challenge through the domain's DNS provider. This can provide a trusted certificate without requiring public service exposure, but it requires a supported DNS provider/API token and a Caddy build with the matching DNS plugin.

## Safety rules

- UniFi Teleport is the current private remote-access path for internal services.
- Do not expose Quick Links or Homarr publicly until there is a clear remote-access redesign.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, and Quick Links LAN/VPN-only unless remote access is intentionally redesigned.
- Do not expose port `8070` directly through router port forwarding, DuckDNS, or a public Caddy route.
- If remote access is redesigned later, prefer a deliberate protected private-access model over raw public exposure.
- Keep all secrets, API keys, passwords, VPN keys, DuckDNS tokens, Mullvad keys, and private keys out of GitHub.

## Next step

1. Use Homarr for desktop and Quick Links for mobile/Teleport access.
2. Add an iPhone Home Screen shortcut for Quick Links.
3. Add one large R515 button in Home Assistant that opens `http://192.168.10.135:8070`.
4. Later fold Quick Links into `docker-compose.yml` or an override file and optionally add the LAN-only `links.allenfamhouse.com` alias.
5. Continue the broader backup/off-server backup plan before installing Immich.
