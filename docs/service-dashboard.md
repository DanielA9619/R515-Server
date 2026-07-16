# Service Dashboard / Central Portal

This document tracks the central landing page for the R515 home server services.

## Goal

Create one internal web page that links to all local services so the user does not need to remember every IP address and port.

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

Known dashboard links:

```text
Jellyfin             https://mediahubdaniel.duckdns.org
Portainer           https://192.168.10.135:9443
Uptime Kuma          http://192.168.10.135:3001
Uptime status page   http://192.168.10.135:3001/status/r515
AdGuard Home         http://192.168.10.135:3002
qBittorrent          http://192.168.10.135:8080
Prowlarr             http://192.168.10.135:9696
Radarr               http://192.168.10.135:7878
Sonarr               http://192.168.10.135:8989
Home Assistant VM    http://192.168.10.127:8123
Proxmox              https://192.168.10.50:8006
```

## Preferred approach

Use Homarr as an internal-only dashboard service first. Do not make it public-facing.

Reasoning:

- Easier to manage visually than editing YAML by hand.
- Designed as a homelab/service dashboard.
- Can be kept LAN-only.
- Can later be reached by a local domain name through AdGuard DNS and/or Caddy.

Other options to consider later:

```text
Homepage
Dashy
```

## Uptime Kuma status integration

Yes, include server status in the central portal.

Current status page:

```text
http://192.168.10.135:3001/status/r515
```

Current first version:

1. Add the Uptime Kuma status page as a prominent card/link in Homarr. Done.
2. Keep the status page LAN-only at first.
3. Later optionally create a cleaner internal DNS name for it.

Later nice internal DNS names:

```text
r515.<house-domain>    -> Homarr / central portal
status.<house-domain>  -> Uptime Kuma status page or Uptime Kuma instance
```

Embedding the Uptime Kuma status page inside the dashboard with an iframe is possible later, but not the first choice. Uptime Kuma requires a special iframe-related setting for embedding, and that has clickjacking/security tradeoffs. A normal card/link is safer and simpler.

## Domain plan

The user has a domain for the house, but a public-facing setup is not needed for the dashboard.

Preferred local dashboard name:

```text
r515.<house-domain>
```

Safer first plan:

1. Run the dashboard on the LAN only.
2. Access it directly by IP/port at first.
3. Later create an internal DNS rewrite in AdGuard:

```text
r515.<house-domain> -> 192.168.10.135
```

4. Initially this may still require port `7575`:

```text
http://r515.<house-domain>:7575
```

5. Optionally use Caddy later so the dashboard can be reached without typing port `7575`:

```text
http://r515.<house-domain>
```

or local HTTPS if that is intentionally configured later.

## Safety rules

- Do not expose the dashboard publicly until there is a clear remote-access design.
- Do not expose Portainer, qBittorrent, Prowlarr, Radarr, Sonarr, Uptime Kuma, AdGuard Home, Proxmox, or Home Assistant directly to the public internet.
- If remote access is needed later, prefer VPN/Tailscale/WireGuard/Cloudflare Access-style protection over raw public exposure.
- Keep all secrets, API keys, passwords, and VPN keys out of GitHub.

## Next step

1. Add Proxmox to Homarr if it is not already present: `https://192.168.10.50:8006`.
2. Create an internal AdGuard DNS rewrite for the dashboard: `r515.<house-domain>` -> `192.168.10.135`.
3. Optionally use Caddy later so the dashboard can be reached without typing port `7575`.
4. Back up `/srv/docker` after the Homarr dashboard is stable.
