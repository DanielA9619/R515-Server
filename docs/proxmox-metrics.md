# Proxmox Metrics

This phase adds read-only Proxmox VE host and VM telemetry to the existing R515 Prometheus/Grafana control plane.

## Architecture

```text
Proxmox VE r515 (192.168.10.50:8006)
        |
        | read-only API token
        v
prometheus-pve-exporter on docker01 (:9221)
        |
        v
Prometheus (:9090)
        |
        +--> Grafana R515 Control Plane V4
        |
        v
Alertmanager -> ntfy.sh -> phone
```

The exporter runs on `docker01`; nothing additional runs on the Proxmox host besides the dedicated read-only API identity.

## Exporter

Project: `prometheus-pve/prometheus-pve-exporter`

Deployed image:

```text
prompve/prometheus-pve-exporter:3.9.0
```

Exporter endpoint:

```text
http://192.168.10.135:9221
```

Prometheus job:

```text
proxmox
```

The Prometheus target is validated `UP` and currently scrapes:

```text
http://192.168.10.135:9221/pve?cluster=1&module=default&node=1&target=192.168.10.50
```

## Security model

Dedicated PVE identity:

```text
user:       prometheus@pve
token:      r515-monitoring
role:       PVEAuditor
scope:      /
privsep:    enabled
```

Both the backing user and privilege-separated token have only `PVEAuditor` access.

The token secret is stored only on `docker01` in:

```text
/srv/docker/monitoring/proxmox-exporter/.env
```

with mode `0600`. It must never be committed to GitHub or pasted into documentation/logs.

Setup scripts:

```text
scripts/setup-proxmox-monitoring-token.sh
scripts/install-proxmox-exporter.sh
scripts/add-proxmox-alerts.sh
```

## TLS

The exporter connects to `192.168.10.50:8006` with:

```text
PVE_VERIFY_SSL=false
```

because the default Proxmox certificate is locally signed and the exporter container does not yet trust the R515 Proxmox CA. A later hardening step can import the Proxmox CA and enable verification.

## Validated live resources

The exporter authenticated successfully and exposed these `pve_up` resources:

```text
node/r515
qemu/100
qemu/101
storage/r515/local-lvm
storage/r515/local
storage/r515/bulk
```

Guest identity is confirmed through `pve_guest_info`:

```text
qemu/100  name=Docker01  node=r515  type=qemu
qemu/101  name=haos      node=r515  type=qemu
```

All six `pve_up` resources were `1` during validation.

## Validated live metrics

Confirmed metrics and labels include:

```text
pve_up{id="node/r515"}
pve_up{id="qemu/100"}
pve_up{id="qemu/101"}
pve_guest_info{id="qemu/100",name="Docker01",node="r515",type="qemu"}
pve_guest_info{id="qemu/101",name="haos",node="r515",type="qemu"}
pve_cpu_usage_ratio{id="node/r515"}
pve_cpu_usage_ratio{id="qemu/100"}
pve_cpu_usage_ratio{id="qemu/101"}
pve_memory_size_bytes
pve_memory_usage_bytes
pve_disk_size_bytes
pve_disk_usage_bytes
pve_network_receive_bytes_total
pve_network_transmit_bytes_total
pve_uptime_seconds
```

Validated capacities during the V4 dashboard preflight:

```text
R515 RAM total          67422552064 bytes
Docker01 RAM total       8589934592 bytes
HAOS RAM total           4294967296 bytes
bulk size             2952325091328 bytes
bulk used             1329746870272 bytes
local size               72594137088 bytes
local used                8466837504 bytes
local-lvm size           151259185152 bytes
local-lvm used            70305269258 bytes
```

These are point-in-time observations and should not be treated as fixed utilization values.

## Grafana Control Plane V4

Control Plane V4 was successfully provisioned from:

```text
/srv/docker/monitoring/grafana/dashboards/r515-control-plane.json
```

Dashboard URL:

```text
https://grafana.r515.allenfamhouse.com/d/r515-control-plane/r515-control-plane
```

The Proxmox section adds:

- Proxmox exporter scrape status;
- R515 node status and uptime;
- VM 100 (`Docker01`) status;
- VM 101 (`haos`) status and uptime;
- R515 host CPU/RAM;
- Docker01 CPU/RAM;
- HAOS CPU/RAM;
- `bulk`, `local`, and `local-lvm` utilization;
- host/guest CPU and RAM trend graphs;
- Docker01 and HAOS network throughput;
- Proxmox storage utilization history.

A pre-V4 dashboard backup was created before the live update.

## Proxmox alerting

Proxmox-specific rules were added to the existing Prometheus rule file with:

```text
scripts/add-proxmox-alerts.sh
```

The post-change validation succeeded:

```text
Prometheus config        valid
alert rule file          valid
rules loaded             27 total
Proxmox scrape down      0
R515 node down           0
Docker01 down            0
HAOS down                0
bulk unavailable         0
local unavailable        0
local-lvm unavailable    0
bulk >85%                0
local >85%               0
local-lvm >85%           0
```

The Proxmox group covers:

- exporter/API scrape failure;
- R515 node reported down;
- Docker01 VM reported down;
- HAOS VM reported down;
- `bulk`, `local`, and `local-lvm` unavailable;
- warning when each storage target stays above 85% used;
- critical when each storage target stays above 95% used.

No real VM or storage outage was induced during validation.

## Whole-host outage limitation

Prometheus and Alertmanager run in Docker01 on the R515. Therefore, a complete host power loss, Proxmox crash, loss of the R515 network path, or hard stop of Docker01 can also stop the monitoring and notification stack.

The internal node/VM alerts are still useful when Docker01 remains alive, but they cannot guarantee notification for a total R515 outage.

The next resilience step is an outbound-only external dead-man heartbeat from the Proxmox host to a hosted monitoring service. If the R515 stops sending heartbeats, the hosted service can notify independently of the server.