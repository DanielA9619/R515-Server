# qBittorrent VPN Setup

This document tracks the qBittorrent + Mullvad VPN setup on the R515 Debian Docker VM.

## Goal

Route qBittorrent through a VPN kill-switch so torrent traffic does not use the normal home WAN path.

Target flow:

```text
qBittorrent container
  -> Gluetun VPN container
  -> Mullvad WireGuard
  -> Internet
```

## Current status

Working as of the latest chat checkpoint.

Confirmed:

- `gluetun` is running and Docker reports it as healthy.
- `qbittorrent` is running behind Gluetun using Gluetun's network stack.
- qBittorrent Web UI is still reachable on the LAN at `http://192.168.10.135:8080`.
- Gluetun publishes qBittorrent's Web UI port with `0.0.0.0:8080->8080/tcp`.
- VPN traffic through Gluetun successfully pinged `1.1.1.1` with `0% packet loss`.
- DNS through Gluetun successfully resolved `cloudflare.com` using Gluetun's local DNS server at `127.0.0.1`.
- Public IP test through Gluetun returned `155.2.191.136`, indicating traffic is exiting through Mullvad rather than the home IP.
- qBittorrent Web UI password was changed from the temporary/default password.
- qBittorrent download paths were confirmed in the Web UI.
- Uptime Kuma qBittorrent monitor was added/confirmed by the user.
- Backup was completed after qBittorrent + Mullvad/Gluetun was confirmed working.

Example successful checks:

```text
gluetun       Up About a minute (healthy)
qbittorrent   Up About a minute
```

```text
PING 1.1.1.1 (1.1.1.1): 56 data bytes
3 packets transmitted, 3 packets received, 0% packet loss
```

```text
Server:         127.0.0.1
Address:        127.0.0.1:53

Name:   cloudflare.com
Address: 104.16.133.229
Name:   cloudflare.com
Address: 104.16.132.229
```

```text
Public IP through Gluetun: 155.2.191.136
```

## Important troubleshooting note

The first VPN attempts failed because the Mullvad account did not have active time added. Symptoms matched a tunnel that initialized but did not pass traffic:

- Gluetun reported WireGuard setup complete.
- Gluetun stayed unhealthy.
- Ping through Gluetun had `100% packet loss`.
- DNS lookups through Gluetun timed out.
- Gluetun repeatedly restarted the VPN healthcheck.

After adding time to the Mullvad account and recreating Gluetun/qBittorrent, the VPN became healthy and traffic tests passed.

## Current secret/config values

Secrets are stored locally in:

```text
/srv/docker/.env
```

Do not commit this file to GitHub.

Expected `.env` variable names:

```env
MULLVAD_PRIVATE_KEY=...
MULLVAD_ADDRESSES=10.x.x.x/32
MULLVAD_SERVER_COUNTRIES=USA
MULLVAD_WIREGUARD_ENDPOINT_PORT=51820
```

Do not paste or publish `MULLVAD_PRIVATE_KEY`.

## Compose design

Gluetun should publish qBittorrent's Web UI port:

```yaml
ports:
  - "8080:8080"
```

qBittorrent should use Gluetun's network stack:

```yaml
network_mode: "service:gluetun"
```

qBittorrent should not have its own `ports:` section while routed through Gluetun.

## Recommended qBittorrent paths

Inside qBittorrent / inside the container:

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

- Do not expose qBittorrent Web UI port `8080` publicly.
- Do not expose Portainer `9443` publicly.
- Do not put Mullvad private keys into GitHub.
- If Gluetun becomes unhealthy, qBittorrent should be treated as offline until VPN tests pass again.
- Before adding automation tools such as Radarr/Sonarr, verify Gluetun is healthy and the public IP test exits through Mullvad.

## Useful test commands

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

## Backup checkpoint

Backup completed after qBittorrent + Mullvad/Gluetun was working.

Expected backup filename:

```text
/mnt/storage/backups/<date>/srv-docker-after-qbit-vpn.tar.gz
```

## Next planned media stack

Recommended next tools:

```text
Prowlarr -> indexer manager
Radarr   -> movies
Sonarr   -> TV
```

These should be installed only after confirming the qBittorrent VPN path is still healthy.
