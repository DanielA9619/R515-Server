# Quick Links Mobile Launcher

This document tracks the lightweight Quick Links page used as a mobile-friendly launcher for the R515 home server.

## Purpose

Homarr remains useful as the richer desktop dashboard, but its icons and text are too cramped on mobile. Quick Links is a deliberately simple launcher that is easier to use from a phone while connected to the home LAN or through UniFi Teleport.

Current launcher targets include:

- Seerr
- Radarr
- Sonarr
- qBittorrent
- Jellyfin
- Uptime Kuma
- Prowlarr
- AdGuard Home
- Portainer
- Proxmox
- Home Assistant
- Homarr

## URL

```text
http://192.168.10.135:8070
```

Access is LAN / UniFi Teleport only.

## Current standalone container

| Item | Value |
| --- | --- |
| Container name | `quicklinks` |
| Image | `nginx:alpine` |
| Host port | `8070` |
| Container port | `80` |
| Local content path | `/srv/docker/quicklinks/index.html` |
| Mounted directory | `/srv/docker/quicklinks` -> `/usr/share/nginx/html:ro` |

Current standalone Docker run command:

```bash
sudo docker run -d --name quicklinks --restart unless-stopped -p 8070:80 -v /srv/docker/quicklinks:/usr/share/nginx/html:ro nginx:alpine
```

## Test commands

Check the HTTP response:

```bash
curl -I http://192.168.10.135:8070
```

Check the container:

```bash
sudo docker ps --filter name=quicklinks
```

## Safety notes

- Quick Links is intended for LAN / UniFi Teleport access only.
- Do not expose port `8070` publicly through Caddy, DuckDNS, router port forwarding, or another public proxy.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, and Quick Links LAN/VPN-only unless remote access is intentionally redesigned.
- The page is a launcher, not an authentication or access-control layer. Access control comes from the LAN / Teleport boundary and each service's own authentication where applicable.
- Do not put passwords, API keys, tokens, DuckDNS tokens, Mullvad keys, private keys, or other secrets into the page or this repository.

## Future improvements

1. Fold Quick Links into the main `docker-compose.yml` or a Compose override file so lifecycle management is consistent with the rest of the Docker stack.
2. Add a LAN-only internal alias such as:

```text
links.allenfamhouse.com
```

3. Add the Quick Links page to the iPhone Home Screen for app-like one-tap access.
4. Add one large R515 button to the Home Assistant dashboard that opens:

```text
http://192.168.10.135:8070
```

This avoids duplicating every individual server-service link inside Home Assistant.
