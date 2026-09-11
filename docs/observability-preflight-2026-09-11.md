# Observability Preflight — 2026-09-11

This records the first read-only preflight for the R515 observability/control-plane project.

## Result

The Debian Docker VM is healthy enough to proceed with Prometheus/Grafana work, but Scrutiny should **not** be deployed inside `docker01` yet.

### Recovery state

Both recovery services were successful:

```text
r515-postboot-recovery.service      active (exited), status=0/SUCCESS
r515-byparr-recovery.service        active (exited), status=0/SUCCESS
```

### Storage

`/mnt/storage` is correctly mounted from `/dev/sdb1` as ext4 and was approximately:

```text
2.6T total
936G used
1.6T available
38% used
```

### Important SMART / virtualization finding

Inside `docker01`, the disks appear as virtual QEMU disks:

```text
/dev/sda  64G   model: QEMU HARDDISK
/dev/sdb  2.6T  model: QEMU HARDDISK
```

`smartctl` is not currently installed in the guest, but the more important point is that `/dev/sdb` is presented to Debian as a virtual QEMU disk rather than clearly exposing the underlying physical drive/controller.

Therefore the Scrutiny design is temporarily changed:

1. do **not** install Scrutiny in `docker01` yet;
2. inspect storage/controller visibility on the Proxmox host first;
3. identify whether the physical disk is visible directly, through a PERC/LSI RAID controller, or only as a virtual disk/volume;
4. place the SMART collector where the physical SMART data is actually available;
5. Grafana/Prometheus may still run in `docker01` regardless of where Scrutiny collects SMART data.

If the R515 uses a PERC/LSI controller, SMART collection may require controller-aware access rather than a simple `/dev/sdb` mapping.

### Resource baseline

At preflight time:

```text
Debian VM RAM: 7.8 GiB total
CPU:           4 vCPUs
Root FS:       60G, ~60% used
P400:          visible and idle, ~30 C
```

Largest observed container memory user was qBittorrent at roughly 2.2 GiB. The observability stack should therefore remain modest initially and retention should be conservative.

### Existing services

The media stack, Caddy, AdGuard, Uptime Kuma, Portainer, Homarr, Quick Links, and recovery services were all running. Byparr and Gluetun were healthy.

### Port / exposure note

Many existing services are already published on host ports. New monitoring components should avoid unnecessary host-port exposure. Prometheus, node_exporter, cAdvisor, Alertmanager, and internal exporters should remain Docker/LAN-internal where possible. Only selected UIs such as Grafana, Scrutiny, and ntfy should receive private Caddy hostnames.

## Next step

Run a read-only storage/controller preflight on the Proxmox host (`192.168.10.50`) before installing Scrutiny.

After physical SMART visibility is understood, continue with:

```text
Scrutiny collector placement
Prometheus + node_exporter + cAdvisor
Grafana
ntfy + Alertmanager
custom R515 metrics/dashboard
```
