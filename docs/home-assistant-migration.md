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
- Only around 3 add-ons are installed.
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

### 4. Cutover

1. Shut down the Raspberry Pi Home Assistant.
2. Keep the Raspberry Pi untouched for several days as a fallback.
3. Update bookmarks, mobile apps, dashboards, and anything else pointing to the old IP.
4. Once the new VM is stable, make a fresh HAOS backup immediately.

## Open details to fill in

- Current Raspberry Pi Home Assistant IP
- Whether Home Assistant currently uses ZHA, Zigbee2MQTT, Z-Wave JS, Matter, Thread, or other USB/radio hardware
- Whether any USB dongles need to be passed through to the HAOS VM
- Whether Home Assistant has external access configured
- Whether Home Assistant uses a custom domain
- Which 3 add-ons are currently installed
- Whether the history database should stay local or eventually move to MariaDB/Postgres
