# Home Assistant Migration Plan

Goal: move Home Assistant from the Raspberry Pi to a dedicated Home Assistant OS VM on Proxmox.

## Recommended architecture

Run Home Assistant as its own HAOS VM, not inside the Debian Docker VM.

Why:

- Easier add-ons and updates
- Cleaner backup/restore
- Better isolation from Jellyfin/Docker services
- Easier rollback if something breaks

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

## Migration steps

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

### 4. Cutover

1. Shut down the Raspberry Pi Home Assistant.
2. Reserve the new HAOS VM IP in UniFi.
3. Update any bookmarks, mobile apps, dashboards, or integrations that point to the old IP.
4. Keep the Raspberry Pi untouched for several days as a fallback.

## Open details to fill in

- Current Raspberry Pi Home Assistant IP
- Whether Home Assistant currently uses ZHA, Zigbee2MQTT, Z-Wave JS, Matter, Thread, or other USB/radio hardware
- Whether any USB dongles need to be passed through to the HAOS VM
- Whether Home Assistant has external access configured
- Whether Home Assistant uses a custom domain
- Whether the history database should stay local or eventually move to MariaDB/Postgres
