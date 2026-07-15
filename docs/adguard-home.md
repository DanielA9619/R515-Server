# AdGuard Home Setup

This document tracks AdGuard Home on the R515 Debian Docker VM.

## Current status

AdGuard Home is installed in Docker on `docker01`.

Current known access:

```text
AdGuard Home dashboard: http://192.168.10.135:3002
DNS server:              192.168.10.135:53
```

The dashboard should remain LAN-only.

## Deployment notes

AdGuard Home was installed with Docker Compose using host networking so DNS can bind to port `53` and so client visibility is better than a normal Docker bridge setup.

Persistent folders:

```text
/srv/docker/adguardhome/work
/srv/docker/adguardhome/conf
```

Important port note:

```text
Do not use ports 80 or 443 for AdGuard Home because Caddy already uses those for Jellyfin.
```

The AdGuard admin dashboard was configured to use port `3002`.

## DNS configuration

Upstream DNS servers configured during setup:

```text
https://dns.quad9.net/dns-query
https://cloudflare-dns.com/dns-query
```

Initial filtering was left conservative with the default AdGuard DNS filter enabled.

## Tests completed

Server-side DNS resolution test from Debian:

```bash
docker run --rm busybox nslookup google.com 192.168.10.135
```

Result: success. `google.com` resolved normally.

Blocking test:

```bash
docker run --rm busybox nslookup doubleclick.net 192.168.10.135
```

Result: success. `doubleclick.net` returned blocked addresses:

```text
::
0.0.0.0
```

One iPhone was manually configured to use DNS server:

```text
192.168.10.135
```

The iPhone appeared in the AdGuard query log, confirming real client DNS traffic is going through AdGuard.

## Current rollout state

AdGuard is working, but whole-network DNS has not been changed yet.

Current safe approach:

1. Continue testing on one iPhone.
2. Watch for broken apps, websites, streaming services, captive portals, or login flows.
3. If something breaks, check the AdGuard query log and allowlist only the needed domain.
4. Add AdGuard Home to Uptime Kuma if not already added.
5. After one-device testing is stable, decide whether to point UniFi DHCP/DNS to AdGuard for the whole LAN.

## Safety rules

- Keep AdGuard Home LAN-only.
- Do not expose AdGuard DNS or admin ports publicly.
- Do not change whole-network DNS until one-device testing is stable.
- Keep a rollback plan: set client DNS back to automatic, or point UniFi DNS back to the gateway/upstream resolver.
- Avoid adding too many blocklists at once; troubleshootability matters more than maximum blocking.