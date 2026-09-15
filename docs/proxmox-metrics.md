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
        v
R515 Control Plane Grafana dashboard
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
pve_memory_usage_bytes{id="node/r515"}
pve_memory_usage_bytes{id="qemu/100"}
pve_memory_usage_bytes{id="qemu/101"}
pve_uptime_seconds{id="node/r515"}
pve_uptime_seconds{id="qemu/100"}
pve_uptime_seconds{id="qemu/101"}
```

Observed validation values included approximately:

```text
R515 CPU ratio       0.152
Docker01 CPU ratio   0.595
HAOS CPU ratio       0.016
R515 RAM used        15.8 GB
Docker01 RAM used     7.6 GB
HAOS RAM used         4.0 GB
```

These are point-in-time observations only, not expected steady-state values.

## Next dashboard work

Before committing the final Grafana Proxmox queries, the remaining exporter series will be live-discovered for:

- total host/guest memory;
- Proxmox storage size/usage;
- guest/network counters;
- any additional node-level metrics useful for the R515 control plane.

The next dashboard revision will then add:

- Proxmox exporter status;
- R515 node status, CPU, RAM, and uptime;
- VM 100 (`Docker01`) status, CPU, RAM, and uptime;
- VM 101 (`haos`) status, CPU, RAM, and uptime;
- `local`, `local-lvm`, and `bulk` storage status/capacity where exposed;
- appropriate Proxmox/VM alert rules after dashboard validation.
