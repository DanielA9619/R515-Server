# Grafana Control Plane

Grafana is the visualization layer of the R515 observability/control-plane project.

## Version

Grafana OSS is pinned to stable `13.2.1`.

## Architecture

```text
node_exporter --------+
cAdvisor -------------+
custom R515 metrics --+--> Prometheus --> Grafana
Proxmox exporter -----+       :9090          :3003
                                           |
                                           v
                          https://grafana.r515.allenfamhouse.com
```

Grafana runs on `docker01` as a separate monitoring Compose stack under:

```text
/srv/docker/monitoring/grafana
```

Direct LAN troubleshooting URL:

```text
http://192.168.10.135:3003
```

Clean private URL:

```text
https://grafana.r515.allenfamhouse.com
```

The clean URL is LAN / UniFi Teleport only and uses the normal Caddy `private_only` gate with internal TLS.

## Current deployment status

Validated state:

```text
container                  grafana
version                    13.2.1
direct port                192.168.10.135:3003
/api/health                healthy
Grafana database           ok
Prometheus datasource      provisioned successfully
clean private URL          working, HTTP 200
anonymous access           disabled
user signup                disabled
R515 Control Plane         provisioned through V4
```

The generated admin credential is stored locally in:

```text
/srv/docker/monitoring/grafana/.env
```

Do not commit this file or its password.

The initially printed password was rotated after deployment. The rotation helper is:

```text
scripts/rotate-grafana-admin-password.sh
```

## Provisioned Prometheus data source

```text
Name: Prometheus
UID:  prometheus
URL:  http://192.168.10.135:9090
```

## R515 Control Plane

Installer/source dashboard script:

```text
scripts/install-r515-control-plane-dashboard.sh
```

Provisioned dashboard file:

```text
/srv/docker/monitoring/grafana/dashboards/r515-control-plane.json
```

Dashboard URL:

```text
https://grafana.r515.allenfamhouse.com/d/r515-control-plane/r515-control-plane
```

### Base host/container section

Includes:

- Prometheus status;
- node_exporter status;
- cAdvisor status;
- `/mnt/storage` mount presence;
- CPU usage;
- RAM usage;
- storage used percentage;
- storage free bytes;
- CPU/RAM history;
- host network RX/TX;
- top Docker containers by CPU and memory.

### R515 custom-health section

Includes:

- storage writable;
- Gluetun health;
- Byparr real `/health` status;
- post-boot recovery status;
- Byparr recovery status;
- config-backup presence;
- custom collector health/freshness;
- latest config-backup age.

### Proxmox V4 section

Control Plane V4 was successfully loaded after validating the required live Proxmox metrics.

It adds:

- Proxmox exporter scrape status;
- R515 node state and uptime;
- VM 100 (`Docker01`) state;
- VM 101 (`haos`) state and uptime;
- R515 CPU/RAM;
- Docker01 CPU/RAM;
- HAOS CPU/RAM;
- `bulk`, `local`, and `local-lvm` utilization;
- Proxmox CPU and RAM trend graphs;
- Docker01/HAOS network-throughput graph;
- Proxmox storage-utilization history.

The V4 update creates a timestamped pre-V4 copy of the dashboard JSON before changing the live file.

## Caddy

Active private route:

```caddyfile
grafana.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy 192.168.10.135:3003
}
```

The route installer follows the safe R515 Caddy workflow: backup, candidate validation, in-place overwrite to preserve the bind-mounted inode, host/container hash comparison, and `SIGUSR1` reload.

## Uptime Kuma

Grafana application health endpoint:

```text
http://192.168.10.135:3003/api/health
```

## Security

- no public WAN port for Grafana;
- no anonymous access;
- public user signup disabled;
- admin password stored locally in a mode-0600 `.env` file;
- exposed initial admin password was rotated;
- private clean URL protected by Caddy `private_only`;
- secrets stay out of GitHub.

## Next step

Visually validate the Proxmox V4 section for correct values, units, thresholds, and graph rendering. After that, add Proxmox-specific alert rules to the existing Prometheus -> Alertmanager -> ntfy pipeline.