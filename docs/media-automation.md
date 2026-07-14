# Media Automation Stack

This document tracks the media automation stack planned around Jellyfin and qBittorrent on the R515 Debian Docker VM.

## Current status

Prowlarr has been installed and initial setup is complete.

Confirmed:

- Prowlarr runs in Docker on `docker01`.
- Prowlarr LAN URL is `http://192.168.10.135:9696`.
- Prowlarr authentication was enabled during first launch.
- qBittorrent was added to Prowlarr as a download client.
- qBittorrent remains routed through Gluetun/Mullvad.
- qBittorrent Web UI remains LAN-only at `http://192.168.10.135:8080`.
- Prowlarr should remain LAN-only.

## Planned service order

```text
Prowlarr -> indexer manager
Radarr   -> movies
Sonarr   -> TV shows
```

## Prowlarr Compose service

Expected service shape:

```yaml
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Denver
    ports:
      - "9696:9696"
    volumes:
      - /srv/docker/prowlarr/config:/config
```

## qBittorrent download client settings in Prowlarr

Preferred settings:

```text
Name: qBittorrent
Host: gluetun first, or 192.168.10.135 if gluetun does not resolve from Prowlarr
Port: 8080
Use SSL: off
URL Base: blank
Category: prowlarr
```

Use the qBittorrent Web UI username/password created during qBittorrent setup.

## Safety rules

- Do not expose Prowlarr port `9696` publicly.
- Do not expose qBittorrent Web UI port `8080` publicly.
- Do not expose Portainer port `9443` publicly.
- Before adding Radarr/Sonarr, confirm Gluetun is healthy and qBittorrent traffic still exits through Mullvad.
- Keep qBittorrent behind Gluetun's network stack.

## Next step

Install Radarr for movie automation, then connect Radarr to:

```text
Prowlarr    -> indexers
qBittorrent -> download client
Jellyfin media folder -> /mnt/storage/media/movies
```
