# Power-Outage / Reboot Recovery

This document tracks the automatic recovery flow added after a September 2026 power outage exposed a boot-order problem on `docker01`.

## Failure observed

After the outage:

- raw service IPs came back before the clean Caddy hostnames;
- public Jellyfin was temporarily unavailable;
- qBittorrent torrents entered `Errored` state;
- Prowlarr indexers were unavailable while Byparr was not ready;
- `/mnt/storage` mounted noticeably later than the Debian VM and Docker startup sequence.

The main storage device is:

```text
/dev/sdb1 -> /mnt/storage
```

The important failure mode is Docker containers starting before the real `/mnt/storage` filesystem is mounted. A bind mount can then attach to the empty underlying directory instead of the mounted 3 TB disk.

## Automatic recovery design

Two systemd oneshot services are enabled on `docker01`.

### Main post-boot recovery

```text
Unit:   r515-postboot-recovery.service
Script: /usr/local/sbin/r515-postboot-recovery.sh
```

Purpose:

1. wait for Docker;
2. start essential non-storage services;
3. wait for `/mnt/storage`;
4. verify the storage filesystem is writable;
5. bring the Compose stack up;
6. recreate Compose containers that bind-mount `/mnt/storage` so they attach to the real mounted filesystem;
7. wait for Gluetun to become healthy;
8. recreate qBittorrent after storage and VPN readiness;
9. report final service status.

The unit is enabled at boot and is expected to finish as:

```text
active (exited)
status=0/SUCCESS
```

### Byparr / Prowlarr recovery

```text
Unit:   r515-byparr-recovery.service
Script: /usr/local/sbin/r515-byparr-recovery.sh
```

It runs after the main post-boot recovery service.

Purpose:

1. ensure Byparr is started;
2. accept Docker `healthy` state when available;
3. while Docker health is still `starting`, use the Byparr `/docs` HTTP endpoint as an application-readiness fallback;
4. recreate Byparr only if it fails to become reachable;
5. restart Prowlarr after Byparr is ready.

Do not automatically pull a new Byparr image during every boot. Image pulls remain a manual troubleshooting step.

## Validated controlled reboot

A controlled Debian VM reboot was performed on September 9, 2026.

After reboot:

```text
/mnt/storage                         mounted read/write from /dev/sdb1
r515-postboot-recovery.service      active (exited), SUCCESS
r515-byparr-recovery.service        active (exited), SUCCESS
qBittorrent                         attached to real /mnt/storage/downloads
Gluetun                             healthy
Byparr                              HTTP endpoint reachable
Jellyfin                            healthy
Quick Links                         HTTP 200
Internal Jellyfin                   HTTP 302
Public Jellyfin                     HTTP 302
Internal DNS                        links.r515.allenfamhouse.com -> 192.168.10.135
```

The qBittorrent storage marker test confirmed that `/downloads` inside the container maps to the currently mounted storage filesystem after recovery.

Byparr may continue to display Docker `health: starting` for some time even while its HTTP application endpoint is already reachable. The boot recovery logic accounts for this rather than treating `starting` alone as failure.

## Useful commands

Check both recovery services:

```bash
sudo systemctl status r515-postboot-recovery.service r515-byparr-recovery.service --no-pager -l
```

View current-boot logs:

```bash
sudo journalctl -u r515-postboot-recovery.service -b --no-pager
sudo journalctl -u r515-byparr-recovery.service -b --no-pager
```

Manually rerun the main recovery service:

```bash
sudo systemctl restart r515-postboot-recovery.service
```

Manually rerun Byparr/Prowlarr recovery:

```bash
sudo systemctl restart r515-byparr-recovery.service
```

Check storage:

```bash
findmnt -T /mnt/storage
df -h /mnt/storage
```

Check Gluetun:

```bash
sudo docker inspect gluetun --format 'Health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
```

Check Byparr application readiness:

```bash
curl -fsS --max-time 5 http://127.0.0.1:8191/docs >/dev/null && echo READY
```

## After a future outage

The expected behavior is automatic recovery with no manual intervention. If something is still unavailable after several minutes, inspect the two systemd units and their current-boot journals before manually recreating containers.

For qBittorrent, do not force-resume torrents if `/mnt/storage` is not mounted. Verify the mount first.

For Prowlarr/Byparr, confirm the Byparr HTTP endpoint is reachable before treating a lingering Docker `health: starting` state as an actual failure.

## Security / safety

- No public exposure changes were made as part of this recovery setup.
- Jellyfin remains the only intentionally public service.
- Internal R515 services remain LAN / UniFi Teleport only.
- qBittorrent remains behind Gluetun/Mullvad.
- Do not commit passwords, tokens, API keys, Mullvad credentials, or private keys.
