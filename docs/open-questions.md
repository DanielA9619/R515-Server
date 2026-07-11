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

Known from Proxmox host `r515`:

```bash
lspci | grep -i nvidia
```

Result:

```text
01:00.0 VGA compatible controller: NVIDIA Corporation GP107GL [Quadro P400] (rev a1)
01:00.1 Audio device: NVIDIA Corporation GP107GL High Definition Audio Controller (rev a1)
```

Detailed host result:

```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107GL [Quadro P400] [10de:1cb3] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: nouveau
        Kernel modules: nvidiafb, nouveau
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel
```

Interpretation:

- Proxmox sees the NVIDIA Quadro P400.
- Debian `docker01` does not currently see the P400.
- Proxmox is binding the GPU to `nouveau` and the audio function to `snd_hda_intel`.
- Next step is GPU passthrough from Proxmox to `docker01`.

Still needed:

1. Confirm IOMMU/AMD-Vi is enabled and active on Proxmox.
2. Bind GPU device IDs `10de:1cb3` and `10de:0fb9` to `vfio-pci`.
3. Add the P400 PCI devices to `docker01`.
4. Install NVIDIA driver and NVIDIA Container Toolkit inside Debian.
5. Current Jellyfin Docker Compose GPU settings, if any.
6. What clients need transcoding? Roku, phone, browser, Fire TV, etc.

## Future services

1. Should Portainer, Uptime Kuma, AdGuard, Immich, and qBittorrent all live in the existing `docker01` VM?
2. Should qBittorrent use a VPN container?
3. Should qBittorrent downloads land in `/mnt/storage/downloads` first, then move into `/mnt/storage/media`?
4. Should Immich use `/mnt/storage/photos` as the library path?
5. Should any dashboards be exposed remotely, or kept LAN-only?
