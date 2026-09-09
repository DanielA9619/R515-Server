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

The fresh HAOS VM is built and usable directly at:

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
- Caddy reverse proxy and clean private HTTPS hostname

The clean-rebuild path was chosen instead of spending more time repairing the Raspberry Pi backup.

## Clean internal URL

Home Assistant is now working through Caddy at:

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

The route is LAN / UniFi Teleport only through the same private Caddy gate used by the other R515 internal services.

## Reverse-proxy trust configuration

Home Assistant initially returned HTTP `400` because it did not trust the Caddy reverse proxy.

The working configuration was added to `/config/configuration.yaml` using Studio Code Server:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.10.135
```

After saving, validating the Home Assistant configuration, and restarting Home Assistant, the clean HTTPS URL worked successfully.

Do not trust `0.0.0.0/0` or an unnecessarily broad network. If the Caddy source address changes later, verify the rejected proxy source in Home Assistant logs before changing `trusted_proxies`.

## IP plan

- Keep the HAOS VM at `192.168.10.127` and reserve that address in UniFi.
- Keep the Raspberry Pi at `192.168.10.190` as fallback for now.
- Do not reuse the Pi IP unless there is a specific compatibility reason.
- Update any old bookmarks, mobile apps, dashboards, or automations that still point at the Pi when final cutover is complete.

## Final cutover checklist

1. Verify devices/integrations on the HAOS VM.
2. Verify Home Assistant mobile app access.
3. Verify Matter and UniFi functionality.
4. Make a fresh HA backup after the completed reverse-proxy/domain setup.
5. Keep the Raspberry Pi untouched until the VM has proven stable.
6. Add one large R515 dashboard button opening:

```text
https://links.r515.allenfamhouse.com
```

This avoids duplicating every individual R515 service inside Home Assistant.

## Safety notes

- Keep `ha.r515.allenfamhouse.com` LAN / UniFi Teleport only.
- Caddy's `private_only` gate must remain on the Home Assistant site.
- Trust only the actual reverse-proxy source in Home Assistant's `trusted_proxies` setting.
- Keep fresh Home Assistant backups before major migration/cutover changes.
- Do not store Home Assistant credentials, tokens, API keys, or private keys in this repository.
