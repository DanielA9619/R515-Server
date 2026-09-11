# R515 Custom Prometheus Metrics

This layer adds R515-specific health signals that generic exporters cannot infer reliably.

## Architecture

A root-run oneshot collector on `docker01` writes Prometheus textfile metrics to:

```text
/var/lib/node_exporter/textfile/r515.prom
```

`node_exporter` exposes them on its existing `/metrics` endpoint and Prometheus scrapes them through the existing `docker01` job.

The collector is refreshed by:

```text
r515-custom-metrics.service
r515-custom-metrics.timer
```

The timer runs every 60 seconds.

## Installer

```text
scripts/install-r515-custom-metrics.sh
```

Run on Debian/docker01 as root.

## Metrics

```text
r515_metrics_collector_success
r515_metrics_generated_unixtime
r515_storage_mounted
r515_storage_writable
r515_gluetun_healthy
r515_byparr_health
r515_postboot_recovery_success
r515_byparr_recovery_success
r515_config_backup_present
r515_config_backup_age_seconds
```

### Storage

`r515_storage_mounted` confirms `/mnt/storage` is actually mounted rather than merely existing as a directory on the root filesystem.

`r515_storage_writable` performs a tiny temporary-file write test only after the mount check passes, then immediately removes the test file.

### Gluetun

`r515_gluetun_healthy` is `1` only when Docker reports Gluetun health status `healthy`.

### Byparr

`r515_byparr_health` checks the real endpoint:

```text
http://127.0.0.1:8191/health
```

This deliberately does not use `/docs`, because `/docs` can remain available while Byparr's browser layer is functionally broken.

### Recovery services

The two recovery metrics require both:

```text
ActiveState=active
ExecMainStatus=0
```

for their respective systemd oneshot units.

### Backup age

The collector finds the newest file matching:

```text
/mnt/storage/backups/**/r515-configs-*.tar.gz
```

`r515_config_backup_present` reports whether one exists, while `r515_config_backup_age_seconds` reports its age in seconds. The age is `-1` if no matching backup exists.

## Next use

These metrics are intended for two consumers:

1. the top health/status section of the `R515 Control Plane` Grafana dashboard;
2. Alertmanager rules, later delivered through ntfy.

Likely initial alert conditions include storage not mounted/writable, Gluetun unhealthy, Byparr unhealthy, recovery failure, missing backup, stale backup, and custom-metric collector staleness.
