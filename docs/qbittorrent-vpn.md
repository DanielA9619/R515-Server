# qBittorrent VPN Setup

This document tracks qBittorrent behind Gluetun/Mullvad on the R515 Debian Docker VM.

## Architecture

```text
Browser on LAN / UniFi Teleport
  -> https://qbittorrent.r515.allenfamhouse.com
  -> Caddy
  -> gluetun:8080
  -> qBittorrent Web UI

qBittorrent torrent traffic
  -> Gluetun VPN namespace
  -> Mullvad WireGuard
  -> Internet
```

## Current status

Working as of September 2026.

Confirmed:

- `gluetun` is healthy.
- qBittorrent uses `network_mode: "service:gluetun"`.
- Gluetun publishes the Web UI on host port `8080`.
- Direct LAN Web UI: `http://192.168.10.135:8080`.
- Preferred private HTTPS Web UI: `https://qbittorrent.r515.allenfamhouse.com`.
- Caddy reverse proxies the clean hostname to `gluetun:8080`.
- qBittorrent Web UI password has been changed from the temporary/default password.
- qBittorrent remains bound to the VPN interface.
- Uptime Kuma monitors qBittorrent.
- after the September power-outage recovery work, a controlled reboot verified that qBittorrent sees the real mounted `/mnt/storage/downloads` path after boot.

## Caddy route

```caddyfile
qbittorrent.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy gluetun:8080
}
```

The route is LAN / UniFi Teleport only. Do not remove the `private_only` import.

The qBittorrent Web UI currently accepts the clean reverse-proxy hostname without disabling its normal Web UI protections.

## VPN checks

Useful checks:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```bash
docker run --rm --network=container:gluetun busybox ping -c 3 1.1.1.1
```

```bash
docker run --rm --network=container:gluetun busybox nslookup cloudflare.com 127.0.0.1
```

```bash
docker run --rm --network=container:gluetun curlimages/curl:latest -s https://ifconfig.me && echo
```

Do not document or commit the resulting VPN public IP as a permanent secret/config value; it may change.

## Interface-binding fix

A previous issue caused torrents to stall with `0` peers even when the same torrent worked elsewhere. The fix was to bind qBittorrent to the VPN interface inside the Gluetun network namespace.

Intended setting:

```text
Tools -> Options -> Advanced
Network Interface: VPN interface / tun0 if available
Optional IP address to bind to: All addresses
```

If needed:

```bash
docker exec gluetun ip addr
docker exec qbittorrent ip addr
```

Because qBittorrent shares Gluetun's network namespace, it should see the same VPN interface.

## September 2026 power-outage failure

After a power outage, qBittorrent came back with torrents in `Errored` state even though the 3 TB disk eventually appeared mounted and writable.

The underlying problem was boot order: Docker could start qBittorrent before `/mnt/storage` had mounted. The bind mount:

```text
/mnt/storage/downloads -> /downloads
```

could therefore attach to the empty underlying mountpoint directory instead of the actual 3 TB filesystem.

The outage logs showed `/dev/sdb1` mounting noticeably after the Debian VM had already started bringing Docker services up.

### Recovery used

The successful manual recovery was:

1. confirm `/mnt/storage` is really mounted;
2. confirm `/mnt/storage/downloads` exists and is writable;
3. ensure Gluetun is healthy;
4. force-recreate qBittorrent so its bind mount is attached to the already-mounted filesystem;
5. verify a marker created on the host under `/mnt/storage/downloads` appears inside the container as `/downloads/...`;
6. force recheck affected torrents;
7. resume normally.

Do not force-resume errored torrents before verifying the real storage mount.

## Automatic boot protection

The enabled systemd service:

```text
r515-postboot-recovery.service
```

runs:

```text
/usr/local/sbin/r515-postboot-recovery.sh
```

Its qBittorrent-related sequence is:

```text
wait for /mnt/storage
  -> verify storage is writable
  -> bring Compose stack up
  -> recreate storage-dependent containers
  -> wait for Gluetun healthy
  -> recreate qBittorrent
```

A controlled reboot verified this flow and the qBittorrent storage-marker test passed afterward.

See [`power-outage-recovery.md`](power-outage-recovery.md) for the full outage/reboot recovery design.

## Secrets

Local VPN secrets are stored in:

```text
/srv/docker/.env
```

Expected variable names include:

```text
MULLVAD_PRIVATE_KEY
MULLVAD_ADDRESSES
MULLVAD_SERVER_COUNTRIES
MULLVAD_WIREGUARD_ENDPOINT_PORT
```

Never commit their values.

## Paths

Container paths:

```text
Default save path: /downloads/complete
Incomplete path:   /downloads/incomplete
Manual imports:    /downloads/qbittorrent or /downloads/complete
```

Host paths:

```text
/srv/docker/qbittorrent/config
/mnt/storage/downloads
/mnt/storage/downloads/complete
/mnt/storage/downloads/incomplete
/mnt/storage/downloads/qbittorrent
```

## Safety rules

- Keep qBittorrent behind Gluetun/Mullvad.
- Keep port `8080` and `qbittorrent.r515.allenfamhouse.com` private/LAN/Teleport-only.
- Do not expose qBittorrent directly to the public internet.
- Do not weaken Host-header/CSRF/clickjacking protections merely to make a reverse proxy work.
- If Gluetun becomes unhealthy, treat qBittorrent as offline until VPN tests pass again.
- After a reboot/outage, verify `/mnt/storage` before troubleshooting torrent-level errors.
- Never commit Mullvad private keys or other credentials.
