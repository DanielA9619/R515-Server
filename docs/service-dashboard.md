# Service Dashboard / Central Portal

This document tracks the plan for a central landing page for the R515 home server services.

## Goal

Create one internal web page that links to all local services so the user does not need to remember every IP address and port.

Possible dashboard links:

```text
Jellyfin             https://mediahubdaniel.duckdns.org
Portainer           https://192.168.10.135:9443
Uptime Kuma          http://192.168.10.135:3001
AdGuard Home         http://192.168.10.135:3002
qBittorrent          http://192.168.10.135:8080
Prowlarr             http://192.168.10.135:9696
Radarr               http://192.168.10.135:7878
Sonarr               http://192.168.10.135:8989
Home Assistant VM    http://192.168.10.127:8123
Proxmox              https://192.168.10.50:8006
```

## Preferred approach

Use an internal-only dashboard service first. Do not make it public-facing.

Recommended first choice:

```text
Homarr
```

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

## Domain plan

The user has a domain for the house, but a public-facing setup is not needed for the dashboard.

Safer first plan:

1. Run the dashboard on the LAN only.
2. Access it directly by IP/port at first.
3. Later create an internal DNS name in AdGuard, such as:

```text
home.<house-domain>
```

4. Point that local DNS name to:

```text
192.168.10.135
```

5. Optionally use Caddy later so the dashboard can be reached without typing a port.

## Safety rules

- Do not expose the dashboard publicly until there is a clear remote-access design.
- Do not expose Portainer, qBittorrent, Prowlarr, Radarr, Sonarr, Uptime Kuma, AdGuard Home, Proxmox, or Home Assistant directly to the public internet.
- If remote access is needed later, prefer VPN/Tailscale/WireGuard/Cloudflare Access-style protection over raw public exposure.
- Keep all secrets, API keys, passwords, and VPN keys out of GitHub.

## Next step

Install Homarr in Docker on `docker01`, keep it LAN-only, then add service links manually.
