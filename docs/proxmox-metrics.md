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

The exporter runs on `docker01`; nothing additional needs to run on the Proxmox host besides a dedicated read-only API identity.

## Exporter

Project: `prometheus-pve/prometheus-pve-exporter`

Initial deployment target: `v3.9.0` / Docker image `prompve/prometheus-pve-exporter:3.9.0`.

The exporter supports Proxmox API token authentication through:

```text
PVE_USER
PVE_TOKEN_NAME
PVE_TOKEN_VALUE
PVE_VERIFY_SSL
PVE_MODULE
```

The R515 deployment binds the exporter only to the docker01 LAN address on TCP `9221` and explicitly listens on IPv4 `0.0.0.0:9221` inside the container.

## Security model

Use a dedicated PVE-realm identity:

```text
user:       prometheus@pve
token:      r515-monitoring
role:       PVEAuditor
scope:      /
privsep:    enabled
```

Both the backing user and the privilege-separated token receive only `PVEAuditor`. The token therefore cannot administer VMs, storage, networking, users, or the node.

The token secret is shown only at creation time. It is stored only on `docker01` in:

```text
/srv/docker/monitoring/proxmox-exporter/.env
```

with mode `0600`, and must never be committed to GitHub.

The read-only user/token creation step has been completed successfully on the R515 Proxmox host.

Create/recreate the user/token on the Proxmox host with:

```text
scripts/setup-proxmox-monitoring-token.sh
```

Deploy the exporter and Prometheus scrape job on docker01 with:

```text
scripts/install-proxmox-exporter.sh
```

The installer prompts interactively for the token value with hidden input on first run; it never prints the secret.

## TLS

The exporter connection targets the Proxmox LAN IP `192.168.10.50`. Because the default Proxmox certificate is locally signed and the exporter container does not yet trust the R515 Proxmox CA, the initial deployment uses:

```text
PVE_VERIFY_SSL=false
```

on this private LAN connection.

A later hardening step can mount/import `/etc/pve/pve-root-ca.pem` into the exporter and enable certificate verification.

## Prometheus scrape design

The exporter runs on docker01 at:

```text
192.168.10.135:9221
```

Prometheus uses the exporter as a proxy for the Proxmox target `192.168.10.50` with `/pve`, module `default`, cluster metrics enabled, and node metrics enabled.

The initial scrape interval is 30 seconds to keep API load light on this single-node homelab.

## Planned Prometheus/Grafana data

After live exporter validation, the R515 dashboard will add:

- Proxmox node up/down state;
- host CPU usage;
- host RAM usage;
- host uptime;
- Proxmox storage capacity/usage;
- VM 100 (`Docker01`) status and resource usage;
- VM 101 (`haos`) status and resource usage;
- guest CPU/RAM/network/disk metrics exposed by the Proxmox API;
- alerts for exporter/Proxmox scrape failure and important VM state changes where appropriate.

Expected core exporter metrics include:

```text
pve_up
pve_cpu_usage_ratio
pve_cpu_usage_limit
pve_memory_size_bytes
pve_memory_usage_bytes
pve_uptime_seconds
pve_disk_size_bytes
pve_disk_usage_bytes
pve_network_receive_bytes_total
pve_network_transmit_bytes_total
pve_guest_info
```

Metric names, labels, and actual node/guest IDs will still be verified against the live R515 exporter before Grafana queries are committed.
