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

Known:

- Current Raspberry Pi Home Assistant backup is having trouble.
- Current Raspberry Pi Home Assistant IP: `192.168.10.190`.
- Current setup is not fully built out yet.
- Only around 3 add-ons/integrations need to be recreated now:
  - HACS
  - Matter Server
  - UniFi Network
- Home Assistant currently uses network-based devices/radios, not USB dongles.
- Remote access is currently enabled.
- Clean rebuild on a new HAOS VM is currently considered acceptable.

Still needed:

1. Do any dashboards, wall tablets, phone apps, bookmarks, or automations point to `192.168.10.190` directly?
2. Does Home Assistant use a custom domain?
3. Which remote access method is used? Home Assistant Cloud/Nabu Casa, port forward, VPN, Cloudflare Tunnel, or something else?

## Jellyfin / GPU transcoding details

Known from inside Debian VM `docker01`:

```bash
lspci | grep -i nvidia
```

Result:

```text
No output
```

```bash
nvidia-smi
```

Result:

```text
-bash: nvidia-smi: command not found
```

Interpretation:

- The NVIDIA Quadro P400 is not currently visible inside `docker01`.
- NVIDIA drivers are not currently installed inside `docker01`.
- Jellyfin hardware transcoding cannot be configured yet from inside Docker.
- Next step is to confirm whether the P400 is visible on the Proxmox host, then pass it through to `docker01`.

Still needed:

1. On the Proxmox host, output of:

```bash
lspci | grep -i nvidia
```

2. On the Proxmox host, output of:

```bash
lspci -nnk | grep -A3 -i nvidia
```

3. Current Jellyfin Docker Compose GPU settings, if any.
4. What clients need transcoding? Roku, phone, browser, Fire TV, etc.

## Future services

1. Should Portainer, Uptime Kuma, AdGuard, Immich, and qBittorrent all live in the existing `docker01` VM?
2. Should qBittorrent use a VPN container?
3. Should qBittorrent downloads land in `/mnt/storage/downloads` first, then move into `/mnt/storage/media`?
4. Should Immich use `/mnt/storage/photos` as the library path?
5. Should any dashboards be exposed remotely, or kept LAN-only?
