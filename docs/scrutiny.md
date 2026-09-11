# Scrutiny SMART Monitoring

Scrutiny is the disk-health layer for the R515 observability/control-plane project.

## Final architecture

The physical disks are directly visible to the Proxmox host through the Dell/LSI SAS2008 controller and `smartctl` can read SMART data there. The Debian Docker VM only sees QEMU virtual disks, so the SMART collector belongs on Proxmox rather than inside `docker01`.

```text
Physical R515 disks
        |
        v
Proxmox host smartctl
        |
Scrutiny collector binary
        |
        | HTTP over private LAN
        v
192.168.10.135:8082
Scrutiny Web/API on docker01
        |
        v
InfluxDB 2.8 on docker01
```

This avoids installing Docker on the Proxmox host solely for Scrutiny.

## Verified physical disk visibility

The Proxmox preflight showed these physical devices:

- `/dev/sda` — SK hynix SC311 SATA 256 GB SSD
- `/dev/sdb` — Seagate ST330006CLAR3000 3 TB SAS HDD; current bulk/media storage device
- `/dev/sdc` — Seagate ST9146853SS 146 GB SAS HDD
- `/dev/sdd` — Seagate ST9146853SS 146 GB SAS HDD

`smartctl --scan-open` detects all four devices and SMART support is available on them.

The storage controller is a Broadcom/LSI SAS2008 using the `mpt3sas` driver.

## Version

Initial deployment is pinned to Scrutiny `v0.9.3` rather than a `latest` tag.

The Proxmox collector installer verifies the official Linux AMD64 collector binary against the release SHA-256 before installing it.

## Current deployment status

Scrutiny hub deployment on `docker01` succeeded.

Current hub state:

```text
scrutiny-influxdb   healthy
scrutiny-web        running
hub API             healthy
```

Direct private endpoint:

```text
http://192.168.10.135:8082
```

The Proxmox collector is installed and working. The initial run completed successfully and published SMART results to the hub. The timer is enabled and runs every 30 minutes.

The collector is a `Type=oneshot` service, so this is the expected state between collection runs:

```text
inactive (dead)
status=0/SUCCESS
```

The active scheduling component is:

```text
scrutiny-collector.timer
```

The Scrutiny UI now lists all four physical R515 drives. All four currently report `Passed`.

The 3 TB media/storage drive is visible as:

```text
/dev/sdb
SEAGATE ST330006CLAR3000
capacity: 2.7 TiB
status: Passed
temperature during first UI validation: 34 C
```

During the first collection, `/dev/sdd` returned smartctl exit code `4` with a checksum warning. Scrutiny still published that device's results and the overall collection completed successfully. The UI subsequently displayed `/dev/sdd` as `Passed`, so the warning should be monitored rather than treated as an immediate failure.

## docker01 hub

Installer:

```text
scripts/install-scrutiny-hub.sh
```

Run on Debian/docker01 as root:

```bash
sudo bash scripts/install-scrutiny-hub.sh
```

The hub lives under:

```text
/srv/docker/monitoring/scrutiny/
```

Services:

- `scrutiny-web`
- `scrutiny-influxdb`

InfluxDB is not intentionally exposed on a host port.

## Proxmox collector

Installer:

```text
scripts/install-scrutiny-proxmox-collector.sh
```

Run on the Proxmox host as root.

The collector binary is installed at:

```text
/opt/scrutiny/bin/scrutiny-collector-metrics
```

Systemd units:

```text
scrutiny-collector.service
scrutiny-collector.timer
```

The timer performs collection every 30 minutes, with an initial collection during installation.

Collector host ID:

```text
r515-proxmox
```

Collector API endpoint:

```text
http://192.168.10.135:8082
```

## Private domain

The clean private Caddy route is installed and validated:

```text
https://scrutiny.r515.allenfamhouse.com
```

Caddy configuration:

```caddyfile
scrutiny.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy 192.168.10.135:8082
}
```

The route was validated before deployment, applied in-place to preserve the single-file bind mount, host/container Caddyfile hashes matched, and the live `/api/health` check returned HTTP 200 after the SIGUSR1 reload.

The raw `8082` endpoint remains a LAN troubleshooting path and is not WAN-forwarded.

## Validation

Phase 1 status:

1. Scrutiny web and InfluxDB are healthy. **PASS**
2. The Proxmox collector service succeeds. **PASS**
3. The UI lists the physical R515 disks. **PASS**
4. The 3 TB Seagate SAS disk appears with real SMART data. **PASS**
5. Historical data starts accumulating. **Collector timer enabled; verify over normal runtime**
6. The clean private Caddy URL works. **PASS**
7. Uptime Kuma has a Scrutiny monitor. **Pending**

## Script convention

R515 maintenance/install scripts should require root once at launch rather than embedding repeated `sudo` calls. Preferred usage is:

```bash
sudo bash script.sh
```

or run from an existing `sudo -i` shell.
