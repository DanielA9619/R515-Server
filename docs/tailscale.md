# Tailscale Remote Access

## Status

Tailscale remote access is installed and validated.

Current design:

- Dedicated unprivileged Debian LXC on Proxmox
- CT ID: `102`
- Hostname: `r515-tailscale`
- Architecture: `amd64`
- Tailscale IP: `100.64.1.83`
- Advertised subnet: `192.168.10.0/24`
- Exit-node mode: disabled
- Autostart: enabled
- `/dev/net/tun` passed through to the LXC

The subnet router is a second private remote-access path alongside UniFi Teleport. It is not part of the qBittorrent/Mullvad path and does not replace the public Jellyfin path.

## Validated behavior

Server-side checks passed:

- LXC running
- `tailscaled` active
- Tailscale authenticated
- subnet `192.168.10.0/24` advertised
- LAN gateway reachable
- Proxmox UI reachable from the router
- Docker01/Prometheus reachable from the router

Client-side validation also passed from both the Windows PC and iPhone. Both clients can reach the home LAN through the Tailscale subnet router.

This proves the end-to-end path:

```text
Windows PC / iPhone
        |
        | Tailscale
        v
r515-tailscale LXC (CT 102)
        |
        | subnet route 192.168.10.0/24
        v
Home LAN / R515 services
```

## Intended use

Use Tailscale for private remote management of services such as:

- Proxmox
- Grafana
- Portainer
- Home Assistant
- Radarr
- Sonarr
- Seerr
- other LAN-only R515 services

Jellyfin remains publicly available through the existing Caddy/DuckDNS path.

qBittorrent remains behind Gluetun/Mullvad and is intentionally separate from Tailscale.

## Notes

The first installation attempt selected an ARM64 Debian template on the AMD64 R515 and failed to start. The failed CT was removed, the incorrect template was removed, and the installer was corrected to force architecture matching before creation.

The working installer is:

```text
scripts/install-tailscale-subnet-router.sh
```

Future reruns should refuse architecture-mismatched templates before creating a container.

## Security model

- Tailscale subnet routing is private; no additional public port forwards were added.
- The Tailscale LXC is not configured as an exit node.
- Existing `private_only` Caddy protections remain in place.
- UniFi Teleport remains available as an independent private-access method.
