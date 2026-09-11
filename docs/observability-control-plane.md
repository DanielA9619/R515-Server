# R515 Observability / Control Plane

This document defines the planned monitoring, alerting, disk-health, and control-plane stack for the R515.

The goal is not just a generic Grafana dashboard. The control plane should answer the questions that have actually mattered on this server: Is the storage really mounted? Is the VPN healthy? Are containers restarting? Is Jellyfin using the P400? Did the boot-recovery units succeed? Is Byparr functionally healthy? Are backups fresh? Is a disk beginning to fail?

## Current decision

Immich is deferred until storage capacity and photo-backup architecture are improved. The next major project is the observability/control-plane stack.

Keep Uptime Kuma. It remains the simple service-availability layer and complements Prometheus/Grafana rather than being replaced by them.

## Target architecture

```text
                           +----------------+
                           |    Grafana     |
                           | control plane  |
                           +-------+--------+
                                   |
                       +-----------+-----------+
                       |                       |
                +------v------+        +-------v-------+
                | Prometheus  |        |  later: Loki  |
                |   metrics   |        |     logs      |
                +------+------+        +---------------+
                       |
       +---------------+-------------------+----------------+
       |               |                   |                |
+------v------+ +------v------+     +------v------+  +------v------+
|node_exporter| |  cAdvisor   |     | PVE exporter|  |custom checks|
|docker01 host| | containers  |     |  Proxmox    |  |R515-specific|
+-------------+ +-------------+     +-------------+  +-------------+

Scrutiny -> SMART / drive health and history
Uptime Kuma -> endpoint / service availability
Alertmanager -> ntfy -> phone notifications
```

## Components

### Grafana

Purpose: primary R515 control-plane UI.

Planned private URL:

```text
https://grafana.r515.allenfamhouse.com
```

Direct troubleshooting fallback will use a LAN-only host port chosen during deployment.

Grafana should be provisioned with Prometheus as a data source rather than relying only on manual UI setup. Dashboard JSON/provisioning files should live under `/srv/docker/monitoring/grafana/` so they are backed up and versionable.

### Prometheus

Purpose: time-series metrics database and scraper.

Initial retention target:

```text
15 days
```

This can be adjusted after observing actual disk use. Prometheus data is useful but not irreplaceable; configuration is more important to back up than the metrics database itself.

Planned scrape interval:

```text
15 seconds
```

Initial scrape targets:

- Prometheus itself
- node_exporter on `docker01`
- cAdvisor for Docker/container metrics
- later: Proxmox VE exporter
- later: custom R515 metrics/textfile collector

### node_exporter

Purpose: Debian VM host metrics, including CPU, memory, load, filesystem, disk I/O, networking, uptime, and filesystem capacity.

Important measurements for this server:

- `/mnt/storage` mounted and capacity/free space
- Debian VM root filesystem capacity
- CPU/RAM/load
- network throughput
- disk I/O
- uptime

Because node_exporter is intended to observe the host, the Docker deployment must use the host root filesystem and host namespaces correctly rather than accidentally monitoring only the container.

### cAdvisor

Purpose: Docker container CPU, memory, network, filesystem, and restart/activity metrics.

Use this to show which containers are consuming resources and to spot unexpected container churn.

Do not expose cAdvisor publicly.

### Scrutiny

Purpose: SMART monitoring and historical disk-health tracking.

Planned private URL:

```text
https://scrutiny.r515.allenfamhouse.com
```

The first deployment must verify which block devices are actually visible inside `docker01` before adding `devices:` entries. The 3 TB storage disk has been seen as `/dev/sdb1` for the filesystem, but Scrutiny needs the whole drive device, expected to be `/dev/sdb`; verify with `lsblk`, `smartctl --scan`, and `smartctl -a` first.

Scrutiny should receive only the device access it needs. Prefer explicit device mappings and `SYS_RAWIO` rather than making the container broadly privileged unless the hardware/controller requires more.

Initial SMART goals:

- overall health
- temperature
- reallocated/pending/uncorrectable sectors
- read/write error trends where available
- historical attribute changes

### ntfy

Purpose: notification endpoint for R515 alerts.

Planned private URL initially:

```text
https://ntfy.r515.allenfamhouse.com
```

Initial deployment stays LAN / UniFi Teleport only. This means phone notifications are only reliable while the phone can reach the private server. If always-away notifications are desired later, design authenticated remote ntfy access separately rather than casually making the server public.

Initial alert topics should use non-secret names and authentication if/when remote access is enabled.

### Alertmanager

Purpose: route Prometheus alerts to ntfy and handle grouping/silencing.

Initial alerts:

- `/mnt/storage` missing or unavailable
- `/mnt/storage` free space below warning/critical thresholds
- Docker container repeatedly restarting
- Gluetun unhealthy
- qBittorrent unavailable while Gluetun should be healthy
- Byparr real `/health` failing
- `r515-postboot-recovery.service` failed
- `r515-byparr-recovery.service` failed
- backup age too old
- disk SMART warning / temperature warning
- host filesystem low space

Alert thresholds should be conservative at first to avoid noisy notifications.

### Proxmox VE exporter

Purpose: show the R515 hypervisor and VM state in Grafana.

Planned after the Docker/Prometheus base stack is stable.

Use a dedicated read-only Proxmox API user/token with the `PVEAuditor` role. Do not use the root account or commit the token to GitHub.

Metrics should include:

- Proxmox node CPU/RAM
- VM state
- VM CPU/RAM
- node storage
- VM uptime/state changes

### Later: Loki

Loki is intentionally not part of the first deployment. Metrics and alerting should be stable first.

Later use cases:

- central Docker logs
- boot-recovery logs
- Caddy logs
- media-stack errors
- correlation from a Grafana panel directly to related logs

Retention should be kept modest because the R515 does not need a large long-term log archive.

## R515 control-plane dashboard

The primary Grafana dashboard should be custom-built for this server rather than relying only on imported community dashboards.

### Top status row

Single-value / status panels:

```text
R515 overall
Storage mounted
Storage free
Gluetun healthy
qBittorrent healthy
Jellyfin healthy
Byparr real health
Prowlarr healthy
Last config backup age
Post-boot recovery result
Byparr recovery result
```

The top row should make a failure obvious without reading graphs.

### Host section

- CPU utilization
- load average
- RAM used/free/cache
- network RX/TX
- root filesystem usage
- `/mnt/storage` usage
- disk I/O latency/throughput where available
- Debian VM uptime

### Docker section

- per-container CPU
- per-container memory
- network traffic
- container state
- restart count/rate
- top resource consumers

Important containers to highlight:

```text
jellyfin
caddy
gluetun
qbittorrent
prowlarr
byparr
radarr
sonarr
seerr
adguardhome
uptime-kuma
portainer
```

### Storage / SMART section

- `/mnt/storage` mount state
- used/free/percentage
- drive SMART overall state
- drive temperature
- critical SMART attributes
- recent SMART trend changes

### Media section

- Jellyfin availability
- P400 GPU utilization / memory / encoder activity if practical
- qBittorrent active downloads and aggregate rates later if exporter/API metrics are added
- Gluetun health
- Byparr `/health`
- Prowlarr status

### Recovery section

The outage work made these first-class metrics:

```text
r515-postboot-recovery.service
r515-byparr-recovery.service
```

Expose last success/failure and preferably last run timestamp using a small local exporter or node_exporter textfile metrics.

### Backup section

Expose:

- newest R515 config backup timestamp
- backup age in hours/days
- newest Windows/off-server copy state later if practical
- Home Assistant backup age later if an API/source is available

## Custom R515 metrics

After the base stack works, create a lightweight script that writes Prometheus textfile metrics for checks that generic exporters do not understand.

Proposed metrics:

```text
r515_storage_mounted 1
r515_storage_writable 1
r515_gluetun_healthy 1
r515_byparr_health 1
r515_postboot_recovery_success 1
r515_byparr_recovery_success 1
r515_config_backup_age_seconds 12345
```

The script must be read-only except for writing its `.prom` output file. It should never restart containers or mutate services.

## Network / exposure policy

All monitoring/admin services remain private.

Planned clean URLs:

```text
https://grafana.r515.allenfamhouse.com
https://scrutiny.r515.allenfamhouse.com
https://ntfy.r515.allenfamhouse.com
```

Each private Caddy site must import `private_only` and use `tls internal`.

Prometheus, Alertmanager, node_exporter, cAdvisor, and exporters do not need public hostnames and should remain on the Docker/LAN network only.

Jellyfin remains the only intentionally public service.

## Directory layout

Planned host layout:

```text
/srv/docker/monitoring/
├── grafana/
│   ├── data/
│   └── provisioning/
├── prometheus/
│   ├── prometheus.yml
│   ├── rules/
│   └── data/
├── alertmanager/
│   └── alertmanager.yml
├── scrutiny/
│   ├── config/
│   └── influxdb/
├── ntfy/
│   ├── cache/
│   └── config/
└── custom-metrics/
```

Secrets and API tokens must remain outside Git-tracked documentation/config examples or use placeholders. Local secret values belong in `/srv/docker/.env` or another appropriately permissioned local secret file.

## Build phases

### Phase 0 - preflight

Before changing Compose:

1. Make a fresh config backup.
2. Record available host ports.
3. Verify current disk devices with `lsblk`.
4. Check SMART visibility with `smartctl --scan` / `smartctl -a`.
5. Record current Docker CPU/RAM use and free space on the Debian VM.
6. Confirm `/mnt/storage` is mounted and healthy.

### Phase 1 - Scrutiny

Install Scrutiny first because it is immediately useful and directly relevant to the future Immich/storage project.

Validation:

- container healthy/running
- actual 3 TB disk appears
- SMART data is populated
- temperature and critical attributes visible
- private Caddy route works
- Uptime Kuma monitor added

### Phase 2 - Prometheus + node_exporter + cAdvisor

Build the base metrics pipeline.

Validation:

- all scrape targets `UP`
- `/mnt/storage` capacity appears in node metrics
- container resource metrics appear in cAdvisor
- Prometheus survives container restart with config intact

### Phase 3 - Grafana

Install Grafana and provision Prometheus.

Validation:

- private Caddy route works
- Prometheus data source reports healthy
- initial host and Docker dashboards display live data
- admin credentials changed from defaults

### Phase 4 - ntfy + Alertmanager

Install private ntfy and Alertmanager.

Validation:

- manual test notification reaches subscribed client while connected to LAN/Teleport
- test Prometheus alert flows through Alertmanager -> ntfy
- no public route exists without a separate security decision

### Phase 5 - custom R515 control plane

Build the custom Grafana dashboard and textfile metrics.

Focus on the checks learned from real failures: mounted storage, Gluetun, Byparr real health, recovery-unit result, backup age, disk health, and container restart activity.

### Phase 6 - Proxmox metrics

Add the PVE exporter using a dedicated read-only API token and expand the dashboard to cover the physical R515 and VMs.

### Phase 7 - optional Loki

Add centralized logs only after the metric/alert stack is stable and resource use is understood.

## Backup policy

Configuration under `/srv/docker/monitoring` should be included in normal Docker/config backups.

Important configuration to preserve:

- Prometheus scrape config and alert rules
- Grafana provisioning and custom dashboard JSON
- Alertmanager config
- ntfy server config
- Scrutiny config
- custom metric scripts

Prometheus historical metrics and Scrutiny/Grafana databases are useful but should not be treated as equivalent to irreplaceable user data.

## Immich relationship

Immich remains planned, but storage comes first.

Before Immich:

1. increase/rework storage capacity;
2. decide primary-vs-backup photo-copy model;
3. design database-aware Immich backup;
4. maintain at least one off-server copy of irreplaceable photos;
5. use Scrutiny/SMART monitoring on the storage involved.

The observability stack should therefore be completed before Immich deployment.

## Immediate implementation order

```text
1. Preflight / backup
2. Scrutiny
3. Prometheus + node_exporter + cAdvisor
4. Grafana
5. ntfy + Alertmanager
6. Custom R515 dashboard/metrics
7. Proxmox exporter
8. Optional Loki
9. Storage expansion
10. Immich
```
