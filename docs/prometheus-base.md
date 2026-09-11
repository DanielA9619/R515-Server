# Prometheus Base Monitoring

This is Phase 2 of the R515 observability/control-plane project.

## Components

- Prometheus `v3.13.3` (current supported 3.13 LTS bugfix line at deployment time)
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

The installer:

1. verifies ports 9090 and 9100 are available;
2. downloads node_exporter v1.12.1 and verifies its official SHA-256;
3. installs node_exporter as `node-exporter.service`;
4. enables the textfile collector at `/var/lib/node_exporter/textfile`;
5. creates Prometheus + cAdvisor under `/srv/docker/monitoring/metrics`;
6. pins Prometheus and cAdvisor versions;
7. configures 15-second scraping and 15-day Prometheus retention;
8. starts the stack;
9. verifies all three scrape targets are `UP`.

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
