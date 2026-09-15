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

The token secret is shown only at creation time. It must be stored only on `docker01` in the local monitoring secret/config and must never be committed to GitHub.

Create the user/token on the Proxmox host with:

```text
scripts/setup-proxmox-monitoring-token.sh
```

## TLS

The initial exporter connection targets the Proxmox LAN IP `192.168.10.50`. Because the default Proxmox certificate is locally signed and the exporter container does not yet trust the R515 Proxmox CA, the initial deployment will use `PVE_VERIFY_SSL=false` on this private LAN connection.

A later hardening step can mount/import `/etc/pve/pve-root-ca.pem` into the exporter and enable certificate verification.

## Planned Prometheus/Grafana data

After exporter validation, the Prometheus job and R515 dashboard will add:

- Proxmox node up/down state;
- host CPU usage;
- host RAM usage;
- host uptime;
- Proxmox storage capacity/usage;
- VM 100 (`Docker01`) status and resource usage;
- VM 101 (`haos`) status and resource usage;
- guest CPU/RAM/network/disk metrics exposed by the Proxmox API;
- alerts for exporter/Proxmox scrape failure and important VM state changes where appropriate.

Metric names and labels will be verified against the live exporter before dashboard queries are committed.
