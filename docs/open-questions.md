# Open Questions

These are the details still needed to fully document and finish the server setup.

## Proxmox / VM details

1. What is the VM ID number for `docker01` in Proxmox?
2. How many CPU cores and how much RAM does `docker01` have?
3. How much disk space is assigned to the Debian VM system disk?
4. Is the 3TB HDD passed through as a whole disk, a virtual disk, or mounted another way?
5. What Proxmox bridge is `docker01` using? Usually something like `vmbr0`.

## Debian / Docker details

1. What is the exact Debian version? Example: Debian 12 Bookworm or Debian 13 Trixie.
2. Are Jellyfin and Caddy managed by Docker Compose?
3. What is the path to the Docker Compose file? Example: `/srv/docker/docker-compose.yml`.
4. What are the exact container names?
5. Are containers set to `restart: unless-stopped`?

## Samba details

1. What is the exact Samba share name? It appears to be `media`.
2. Is the Samba share private to the `daniel` user or guest-accessible?
3. Are write permissions working from Windows for all folders?

## Home Assistant details

1. What is the current Raspberry Pi Home Assistant IP?
2. What hardware does Home Assistant use for Matter/Thread/Zigbee/Z-Wave?
3. Does Home Assistant use an Aqara M100, Inovelli devices, or any USB dongles?
4. Does Home Assistant currently have remote access configured?
5. Do any dashboards, wall tablets, phone apps, or automations point to the Pi IP directly?

## Jellyfin / GPU transcoding details

1. Is the P400 passed through to `docker01`, or is it only visible on the Proxmox host right now?
2. Output of this command inside Debian:

```bash
lspci | grep -i nvidia
```

3. Output of this command inside Debian, if NVIDIA drivers are installed:

```bash
nvidia-smi
```

4. Current Jellyfin Docker Compose GPU settings, if any.
5. What clients need transcoding? Roku, phone, browser, Fire TV, etc.

## Future services

1. Should Portainer, Uptime Kuma, AdGuard, Immich, and qBittorrent all live in the existing `docker01` VM?
2. Should qBittorrent use a VPN container?
3. Should qBittorrent downloads land in `/mnt/storage/downloads` first, then move into `/mnt/storage/media`?
4. Should Immich use `/mnt/storage/photos` as the library path?
5. Should any dashboards be exposed remotely, or kept LAN-only?
