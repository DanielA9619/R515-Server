# AdGuard Home Setup

This document tracks AdGuard Home on the R515 Debian Docker VM.

## Current status

AdGuard Home is installed in Docker on `docker01` and is used as the DNS server for the main/default UniFi LAN.

```text
Dashboard direct:  http://192.168.10.135:3002
Dashboard clean:   https://adguard.r515.allenfamhouse.com
DNS server:        192.168.10.135:53
```

The dashboard remains LAN / UniFi Teleport only.

## Deployment notes

AdGuard Home uses host networking so DNS can bind to port `53` and client visibility is better than with a normal Docker bridge.

Persistent folders:

```text
/srv/docker/adguardhome/work
/srv/docker/adguardhome/conf
```

Do not use ports `80` or `443` for the AdGuard admin UI because Caddy owns those ports. The AdGuard admin UI uses port `3002` directly.

## DNS configuration

Configured upstream DNS servers:

```text
https://dns.quad9.net/dns-query
https://cloudflare-dns.com/dns-query
```

Filtering started conservatively with the default AdGuard DNS filter, then HaGeZi's Normal Blocklist was added.

## R515 internal DNS

AdGuard now provides the private service namespace used by Caddy:

```text
*.r515.allenfamhouse.com -> 192.168.10.135
r515.allenfamhouse.com   -> 192.168.10.135
```

This allows private hostnames such as:

```text
links.r515.allenfamhouse.com
seerr.r515.allenfamhouse.com
radarr.r515.allenfamhouse.com
sonarr.r515.allenfamhouse.com
qbittorrent.r515.allenfamhouse.com
uptime.r515.allenfamhouse.com
prowlarr.r515.allenfamhouse.com
portainer.r515.allenfamhouse.com
adguard.r515.allenfamhouse.com
proxmox.r515.allenfamhouse.com
ha.r515.allenfamhouse.com
homarr.r515.allenfamhouse.com
jellyfin.r515.allenfamhouse.com
```

The wildcard DNS rewrite is convenience/routing, not the only security boundary. Since WAN port `443` reaches Caddy for public Jellyfin, Caddy also enforces a `private_only` remote-IP gate on every private R515 hostname.

## Tests completed

Server-side DNS resolution:

```bash
docker run --rm busybox nslookup google.com 192.168.10.135
```

Blocking test:

```bash
docker run --rm busybox nslookup doubleclick.net 192.168.10.135
```

Expected blocked result includes `0.0.0.0` / `::`.

Internal wildcard test:

```bash
nslookup links.r515.allenfamhouse.com 192.168.10.135
```

Expected result:

```text
192.168.10.135
```

The main/default UniFi LAN DHCP DNS setting is:

```text
DNS Server 1: 192.168.10.135
DNS Server 2: blank
```

The user confirmed whole-network DNS works.

## iPhone privacy choice

The user prefers to keep iPhone privacy features such as Limit IP Address Tracking / Private Relay enabled.

Expected tradeoff:

- some iPhone DNS traffic may bypass AdGuard depending on app/browser/private DNS behavior;
- other normal LAN clients using DHCP DNS should use AdGuard unless they have their own DoH/VPN/private DNS configuration.

## Rollout / troubleshooting

1. Watch the AdGuard query log for clients and failures.
2. If an app/site breaks, identify the blocked domain and allowlist only what is needed.
3. Keep AdGuard monitored in Uptime Kuma.
4. Keep a rollback path ready.
5. If R515 internal hostnames stop resolving, verify the wildcard rewrite before changing Caddy.

## Safety rules

- Keep AdGuard DNS and the admin UI private.
- Do not expose DNS port `53`, admin port `3002`, or the clean AdGuard hostname publicly.
- Keep a rollback plan: set UniFi DHCP DNS back to Auto or the previous resolver if needed.
- Avoid adding many blocklists at once.
- Do not add `1.1.1.1` or `8.8.8.8` as DHCP secondary DNS if the goal is consistent AdGuard use.
- Do not store secrets or credentials in this repository.
