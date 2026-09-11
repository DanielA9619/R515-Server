# Prometheus Base Monitoring

This is Phase 2 of the R515 observability/control-plane project.

## Components

- Prometheus `v3.13.3`
- node_exporter `v1.12.1`
- cAdvisor `v0.60.5`

## Architecture

```text
docker01 host metrics
        |
 native node_exporter
 192.168.10.135:9100
        |
        v
 Prometheus container <--- cAdvisor container
 192.168.10.135:9090      Docker/container metrics
        |
        v
 later: Grafana
```

node_exporter is installed natively rather than containerized so it sees the Debian VM's actual host namespaces and filesystems cleanly. It also provides a textfile collector directory for future R515-specific metrics.

cAdvisor runs in Docker and is not published on a host port. Prometheus reaches it on the private Compose network.

## Installer

```text
scripts/install-prometheus-base.sh
```

Run on Debian/docker01 as root:

```bash
sudo bash scripts/install-prometheus-base.sh
```

The installer is intended to be safe to rerun after a partial deployment. It detects an already-running node_exporter service and continues rather than treating port `9100` as an unexpected conflict.

The installer:

1. checks required tools and relevant ports;
2. downloads node_exporter v1.12.1 and verifies its SHA-256 when installation is needed;
3. installs/enables `node-exporter.service`;
4. enables the textfile collector at `/var/lib/node_exporter/textfile`;
5. creates Prometheus + cAdvisor under `/srv/docker/monitoring/metrics`;
6. pins Prometheus and cAdvisor versions;
7. configures 15-second scraping and 15-day Prometheus retention;
8. starts the stack;
9. verifies all three scrape targets are `UP`.

## September 11, 2026 partial-run note

The first Phase 2 run successfully installed and started node_exporter, but the installer falsely reported that node_exporter was not ready. The readiness check piped the large `/metrics` response directly to `grep -q`; once `grep` found the requested metric it exited early, causing `curl` to report write error `23` / connection reset while node_exporter itself remained healthy and active.

The server state from that run showed:

```text
node-exporter.service: active (running)
listener: 192.168.10.135:9100
```

No Prometheus or cAdvisor deployment occurred after that false failure because the script exited before reaching the Compose stage.

The installer was corrected to download the metrics response to a temporary file before checking it and to support resuming after an already-running node_exporter deployment.

## Endpoints

```text
Prometheus:    http://192.168.10.135:9090
node_exporter: http://192.168.10.135:9100/metrics
cAdvisor:      Docker-network only
```

Prometheus and node_exporter are private LAN endpoints and should not be WAN-forwarded.

## Prometheus scrape jobs

```text
prometheus
docker01
cadvisor
```

## Future textfile metrics

The native node_exporter deployment reserves:

```text
/var/lib/node_exporter/textfile
```

for later custom metrics such as:

```text
r515_storage_mounted
r515_storage_writable
r515_gluetun_healthy
r515_byparr_health
r515_postboot_recovery_success
r515_byparr_recovery_success
r515_config_backup_age_seconds
```

## Validation target

Phase 2 is complete when:

- node_exporter service is active;
- Prometheus is ready;
- `prometheus` target is UP;
- `docker01` target is UP;
- `cadvisor` target is UP;
- `/mnt/storage` filesystem metrics are visible through node_exporter;
- per-container metrics are visible through cAdvisor;
- normal config backup includes the monitoring configuration.
