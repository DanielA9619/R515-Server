# Home Assistant Migration Plan

Goal: run Home Assistant as a dedicated Home Assistant OS VM on Proxmox rather than on the Raspberry Pi.

## Current architecture

Home Assistant now runs as its own HAOS VM on the R515 Proxmox host.

Why this architecture was chosen:

- cleaner isolation from Docker/Jellyfin services
- easier HAOS add-ons and updates
- easier backup/restore
- simpler rollback while the Raspberry Pi remains available as fallback

## Current VM

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
| Disk | `64 GB` |
| Network | `virtio`, bridge `vmbr0` |
| Start at boot | enabled |
| Current IP | `192.168.10.127` |

The Raspberry Pi remains available at `192.168.10.190` as a fallback while the VM is finalized.

## Current HAOS status

The fresh HAOS VM is built and usable at:

```text
http://192.168.10.127:8123
```

Completed on the fresh VM:

- Home Assistant onboarding and account setup
- HACS
- Matter Server
- Terminal & SSH
- Studio Code Server
- Home Assistant Google Drive Backup
- UniFi integration/add-on work
- fresh HA backup after core setup

The clean-rebuild path was chosen instead of spending more time repairing the Raspberry Pi backup.

## Clean internal URL

Caddy now has a private internal route for:

```text
https://ha.r515.allenfamhouse.com
```

Caddy route:

```caddyfile
ha.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy 192.168.10.127:8123
}
```

The route is currently reaching Home Assistant but returns HTTP `400` because Home Assistant has not yet been configured to trust the reverse proxy.

## Remaining reverse-proxy step

After requesting `https://ha.r515.allenfamhouse.com`, check the Home Assistant log for the rejected reverse-proxy source IP.

If the log confirms the source as `192.168.10.135`, add this to `/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.10.135
```

Use the exact source IP Home Assistant reports; do not trust `0.0.0.0/0` or unnecessarily broad networks.

Then:

1. Check the Home Assistant configuration.
2. Restart Home Assistant.
3. Open `https://ha.r515.allenfamhouse.com` again.
4. Confirm login, dashboards, integrations, and WebSocket/live updates work normally.

## IP plan

- Keep the HAOS VM at `192.168.10.127` and reserve that address in UniFi.
- Keep the Raspberry Pi at `192.168.10.190` as fallback for now.
- Do not reuse the Pi IP unless there is a specific compatibility reason.
- Update any old bookmarks, mobile apps, dashboards, or automations that still point at the Pi when final cutover is complete.

## Final cutover checklist

1. Finish the reverse-proxy trusted-proxy setting.
2. Verify devices/integrations on the HAOS VM.
3. Verify Home Assistant mobile app access.
4. Verify Matter and UniFi functionality.
5. Make a fresh HA backup.
6. Keep the Raspberry Pi untouched until the VM has proven stable.
7. Add one large R515 dashboard button opening:

```text
https://links.r515.allenfamhouse.com
```

This avoids duplicating every individual R515 service inside Home Assistant.

## Safety notes

- Keep `ha.r515.allenfamhouse.com` LAN / UniFi Teleport only.
- Caddy's `private_only` gate must remain on the Home Assistant site.
- Trust only the actual reverse-proxy source in `trusted_proxies`.
- Keep fresh Home Assistant backups before major migration/cutover changes.
- Do not store Home Assistant credentials, tokens, API keys, or private keys in this repository.
