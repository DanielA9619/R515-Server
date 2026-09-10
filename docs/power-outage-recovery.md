# Power-Outage / Reboot Recovery

This document tracks the automatic recovery flow added after a September 2026 power outage exposed boot-order, storage-mount, and Byparr DNS/readiness problems on `docker01`.

## Failure observed

After the outage:

- raw service IPs came back before the clean Caddy hostnames;
- public Jellyfin was temporarily unavailable;
- qBittorrent torrents entered `Errored` state;
- Prowlarr indexers failed while Byparr was not actually able to reach public sites;
- `/mnt/storage` mounted noticeably later than the Debian VM and Docker startup sequence.

The main storage device is:

```text
/dev/sdb1 -> /mnt/storage
```

The main storage failure mode was Docker containers starting before the real `/mnt/storage` filesystem was mounted. A bind mount can then attach to the empty underlying directory instead of the mounted 3 TB disk.

A second, separate failure affected Byparr: the Byparr web server could be reachable while Camoufox/browser requests still failed DNS resolution. `/docs` returning `200` was therefore not sufficient proof that Byparr was usable.

## Final automatic recovery design

Two systemd oneshot services are enabled on `docker01`.

### 1. Main post-boot recovery

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

Expected successful state:

```text
active (exited)
status=0/SUCCESS
```

### 2. Byparr / Prowlarr recovery v5

```text
Unit:   r515-byparr-recovery.service
Script: /usr/local/sbin/r515-byparr-recovery.sh
```

This unit runs after `r515-postboot-recovery.service`.

Final behavior:

1. ensure Byparr is running;
2. call the real Byparr `/health` endpoint rather than using `/docs` as the readiness test;
3. require the expected `"msg":"Byparr is working!"` response;
4. if real health fails, recreate Byparr at most once per boot;
5. avoid a repeated destructive recreate loop by using `/run/r515-byparr-recreated-this-boot` as a per-boot marker;
6. restart Prowlarr only after Byparr passes the real health check;
7. allow systemd to retry the oneshot after a failure without repeatedly recreating Byparr.

Byparr is configured with independent public DNS:

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

This intentionally removes Byparr's public scraping/browser traffic from dependency on the local AdGuard instance. AdGuard still provides the LAN/internal `*.r515.allenfamhouse.com` DNS namespace.

Do not automatically pull a new Byparr image during every boot. Image pulls remain a manual troubleshooting step.

## Bugs found while building the recovery flow

Two intermediate recovery versions were intentionally superseded:

- An early version treated `/docs` as sufficient readiness. This could pass while Byparr's browser still had broken DNS.
- v4 wrote the health response to `/tmp/byparr-real-health`. The systemd service received `Permission denied`, falsely declared Byparr unhealthy, recreated it, and retried every minute.

v5 no longer writes the health result to that `/tmp` path. It captures the response in memory and validates the real `/health` payload.

## Validated recovery checkpoints

A controlled Debian VM reboot on September 9, 2026 verified the main boot recovery path:

```text
/mnt/storage                         mounted read/write from /dev/sdb1
r515-postboot-recovery.service      active (exited), SUCCESS
r515-byparr-recovery.service        active (exited), SUCCESS
qBittorrent                         attached to real /mnt/storage/downloads
Gluetun                             healthy
Jellyfin                            healthy
Quick Links                         HTTP 200
Internal Jellyfin                   HTTP 302
Public Jellyfin                     HTTP 302
Internal DNS                        links.r515.allenfamhouse.com -> 192.168.10.135
```

The qBittorrent storage marker test confirmed that `/downloads` inside the container maps to the currently mounted storage filesystem after recovery.

After the reboot, a later Prowlarr failure exposed the Byparr DNS issue. Byparr `/health` returned `502` with `NS_ERROR_UNKNOWN_HOST` while `/docs` still returned `200`. Byparr was changed to `1.1.1.1` and `8.8.8.8`; the real `/health` endpoint then returned `200` and `Byparr is working!`.

The final v5 recovery service completed as `active (exited)` with `status=0/SUCCESS`, restarted Prowlarr, and Prowlarr's indexer tests were all green.

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

Run the Byparr recovery without making the terminal appear stuck:

```bash
sudo systemctl restart --no-block r515-byparr-recovery.service
sudo journalctl -fu r515-byparr-recovery.service
```

Check storage:

```bash
findmnt -T /mnt/storage
df -h /mnt/storage
```

Confirm qBittorrent is attached to the live storage mount with a marker file if needed.

Check Gluetun:

```bash
sudo docker inspect gluetun --format 'Health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
```

Check real Byparr health:

```bash
curl -i --max-time 15 http://127.0.0.1:8191/health
```

Expected result:

```text
HTTP/1.1 200 OK
{"msg":"Byparr is working!", ...}
```

Confirm Byparr's configured DNS:

```bash
CID=$(sudo docker compose -f /srv/docker/docker-compose.yml ps -q byparr)
sudo docker inspect "$CID" --format 'Byparr DNS={{json .HostConfig.Dns}}'
```

Expected:

```text
Byparr DNS=["1.1.1.1","8.8.8.8"]
```

## After a future outage

Expected behavior is automatic recovery with no manual intervention. If something is still unavailable after several minutes, inspect the two systemd units and their current-boot journals before manually recreating containers.

For qBittorrent, do not force-resume torrents if `/mnt/storage` is not mounted. Verify the mount first. If qBittorrent started against the wrong underlying directory, recreate it after the disk is mounted and then force recheck the affected torrents.

For Prowlarr/Byparr, use `/health`, not `/docs`, as the functional test. A reachable Swagger/docs page only proves the FastAPI web server is up; it does not prove Camoufox/browser DNS and outbound access are working.

## Security / safety

- No public exposure changes were made as part of this recovery setup.
- Jellyfin remains the only intentionally public service.
- Internal R515 services remain LAN / UniFi Teleport only.
- qBittorrent remains behind Gluetun/Mullvad.
- Byparr remains LAN-only on port `8191`.
- Do not commit passwords, tokens, API keys, Mullvad credentials, or private keys.
