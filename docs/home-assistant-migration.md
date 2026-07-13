# Home Assistant Migration Plan

Goal: move Home Assistant from the Raspberry Pi to a dedicated Home Assistant OS VM on Proxmox.

## Recommended architecture

Run Home Assistant as its own HAOS VM, not inside the Debian Docker VM.

Why:

- Easier add-ons and updates
- Cleaner backup/restore
- Better isolation from Jellyfin/Docker services
- Easier rollback if something breaks

## Current decision point

The Raspberry Pi Home Assistant backup is having trouble, and the current setup is not fully built out yet.

Known current state:

- Home Assistant is still on the Raspberry Pi.
- Current Raspberry Pi Home Assistant IP: `192.168.10.190`.
- Only around 3 add-ons are installed.
- Current add-ons/integrations to recreate/document:
  - HACS
  - Matter Server
  - UniFi Network
- Home Assistant hardware/radio approach: network-based devices, not USB dongles.
- Remote access is currently enabled.
- The setup is small enough that a clean rebuild is reasonable.

Recommendation:

If the backup keeps failing, do **not** spend hours fighting it. Build a fresh HAOS VM and manually recreate the current setup.

This is probably better than importing a broken or messy early configuration, especially because the current install is not mature yet.

## Suggested VM resources

Starting point:

| Resource | Suggested value |
| --- | --- |
| VM type | Home Assistant OS VM |
| CPU | 2 cores |
| RAM | 4 GB |
| Disk | 32 GB minimum, 64 GB preferred |
| Network | Bridged to main LAN |
| IP | Static DHCP reservation after first boot |

These can be adjusted later depending on add-ons, history database size, and integrations.

## HAOS VM created on Proxmox

A dedicated Home Assistant OS VM was created on the Proxmox host `r515`.

VM configuration:

| Item | Value |
| --- | --- |
| VMID | `101` |
| Name | `haos` |
| HAOS image | `haos_ova-18.1.qcow2` |
| Storage | `local-lvm` |
| Machine | `q35` |
| BIOS | `ovmf` / UEFI |
| CPU | `host`, 2 cores |
| RAM | `4096 MB` |
| Disk | `64 GB` on `scsi0` |
| EFI disk | `local-lvm:vm-101-disk-1`, 4 MB |
| Network | `virtio`, bridge `vmbr0` |
| MAC | `BC:24:11:5D:26:8C` |
| Serial console | `serial0 socket` |
| VGA | `serial0` |
| Start at boot | enabled |
| Status after creation | running |
| Temporary DHCP IP | `192.168.10.127` |

Guest-agent network check showed the LAN interface `enp6s18` with MAC `bc:24:11:5d:26:8c` and IPv4 address `192.168.10.127/24`.

Important note: the Raspberry Pi Home Assistant is still using `192.168.10.190`, so the new HAOS VM should use the temporary DHCP IP first. Do not move `192.168.10.190` to the VM until the Pi is shut down or moved to a different IP.

Next step: open Home Assistant at `http://192.168.10.127:8123` and complete the initial setup or restore path.

## Option A: Backup/restore migration

Use this path only if backup starts working cleanly.

### 1. On Raspberry Pi Home Assistant

1. Go to **Settings → System → Backups**.
2. Create a **full backup**.
3. Download the backup file to a PC.
4. Do not wipe or change the Raspberry Pi yet.

### 2. On Proxmox

1. Download the current HAOS KVM/qcow2 image.
2. Create a new VM.
3. Import the HAOS disk image.
4. Attach the imported disk to the VM.
5. Set boot order to the HAOS disk.
6. Start the VM.
7. Let Home Assistant boot fully.

### 3. Restore backup

1. Open the new Home Assistant setup page.
2. Choose restore from backup.
3. Upload the full backup from the Raspberry Pi.
4. Wait for restore and reboot.
5. Confirm integrations, devices, dashboards, automations, and add-ons work.

## Option B: Clean rebuild migration

Use this path if backup continues failing.

### 1. Before touching the Raspberry Pi

Document the existing Home Assistant setup:

- Screenshot or list all installed add-ons.
- Screenshot or list all integrations.
- Screenshot dashboards you care about.
- Write down any automations, helpers, scenes, scripts, or custom cards worth keeping.
- Record whether any mobile apps, tablets, bookmarks, or automations point directly to the Raspberry Pi IP.
- Record current remote access settings before shutting down the Pi.

Current known items to recreate:

- HACS
- Matter Server
- UniFi Network
- Network-based Matter/Thread setup, no known USB dongles
- Remote access setup

### 2. Build the HAOS VM

1. Create a dedicated HAOS VM in Proxmox.
2. Start Home Assistant OS.
3. Complete the initial setup.
4. Reserve the new HAOS VM IP in UniFi.
5. Reinstall only the add-ons and integrations you actually use.

### 3. Rebuild devices and dashboards

Recommended order:

1. Core Home Assistant setup and user account.
2. Network/static IP reservation.
3. Matter/Thread/Zigbee/Z-Wave integrations.
4. Important devices.
5. Add-ons.
6. Automations.
7. Dashboards.
8. Mobile app connection.
9. Remote access.

### 4. Cutover

1. Shut down the Raspberry Pi Home Assistant.
2. Keep the Raspberry Pi untouched for several days as a fallback.
3. Update bookmarks, mobile apps, dashboards, and anything else pointing to the old IP.
4. Confirm remote access works on the new VM.
5. Once the new VM is stable, make a fresh HAOS backup immediately.

## Open details to fill in

- Whether any dashboards, mobile apps, tablets, bookmarks, or automations point directly to `192.168.10.190`
- Whether Home Assistant uses a custom domain
- Whether the history database should stay local or eventually move to MariaDB/Postgres
