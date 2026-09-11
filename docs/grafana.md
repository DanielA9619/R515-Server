# Grafana Control Plane

Grafana is Phase 3 of the R515 observability/control-plane project.

## Version

Initial deployment is pinned to stable Grafana OSS `13.2.1`.

The September 10, 2026 `13.3.0-*` builds are nightly/development builds, so the R515 stays on the stable 13.2.1 release for this deployment.

## Architecture

```text
node_exporter ----+
                  |
cAdvisor ----------+--> Prometheus --> Grafana
                  |       :9090          :3003
custom metrics ---+                       |
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

Grafana 13.2.1 is installed and running on `docker01`.

Validated state:

```text
container                  grafana
direct port                192.168.10.135:3003
/api/health                healthy
Grafana database           ok
Prometheus datasource      provisioned successfully
clean private URL          working, HTTP 200
anonymous access           disabled
user signup                disabled
R515 Control Plane V1      provisioned
```

Prometheus is provisioned automatically as the default datasource.

The generated admin credential is stored locally in:

```text
/srv/docker/monitoring/grafana/.env
```

Do not commit this file or its password.

The initially printed password was rotated after deployment. The rotation helper is:

```text
scripts/rotate-grafana-admin-password.sh
```

The helper uses the Grafana CLI to reset the password in the Grafana database and then updates the local `.env` copy so the local credential record stays in sync.

## Installer

```text
scripts/install-grafana.sh
```

Run on Debian/docker01 as root:

```bash
sudo bash scripts/install-grafana.sh
```

The installer:

1. verifies Prometheus readiness;
2. verifies port 3003 is available;
3. creates Grafana persistent storage and provisioning directories;
4. generates a local admin password on first install and stores it only in `/srv/docker/monitoring/grafana/.env`;
5. provisions Prometheus as the default Grafana data source;
6. creates an `R515` dashboard-provisioning folder;
7. starts pinned Grafana 13.2.1;
8. verifies `/api/health` and the Prometheus data source.

Do not commit the generated `.env` or its password to GitHub.

## Provisioned Prometheus data source

Grafana is configured with:

```text
Name: Prometheus
UID:  prometheus
URL:  http://192.168.10.135:9090
```

This avoids manual data-source setup and keeps the monitoring stack reproducible.

## R515 Control Plane V1

Installer:

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

V1 currently contains:

- Prometheus status;
- node_exporter status;
- cAdvisor status;
- `/mnt/storage` mount presence;
- CPU usage;
- RAM usage;
- storage used percentage;
- storage free bytes;
- CPU history;
- RAM history;
- host network RX/TX;
- top Docker containers by CPU;
- top Docker containers by memory.

The next dashboard expansion will add R515-specific custom metrics for storage writability, Gluetun, Byparr real health, recovery-service results, and backup age. SMART/Proxmox data will be integrated after the relevant exporters/metrics are wired into Prometheus.

## Caddy

The active private route is:

```caddyfile
grafana.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy 192.168.10.135:3003
}
```

The route installer is:

```text
scripts/add-grafana-caddy-route.sh
```

It follows the safe R515 Caddy workflow: backup, candidate validation, in-place overwrite to preserve the bind-mounted inode, host/container hash comparison, and `SIGUSR1` reload.

The route was validated with HTTP 200 through the clean hostname.

## Uptime Kuma

Grafana application health endpoint:

```text
http://192.168.10.135:3003/api/health
```

This checks Grafana itself rather than Caddy. Uptime Kuma remains the simple availability layer while Prometheus/Grafana handles metrics and deeper health.

## Security

- no public WAN port for Grafana;
- no anonymous access;
- public user signup disabled;
- generated admin password stored locally in a mode-0600 `.env` file;
- exposed initial admin password was rotated after deployment;
- private clean URL protected by Caddy `private_only`;
- secrets stay out of GitHub.
