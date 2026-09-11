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

Planned clean private URL:

```text
https://grafana.r515.allenfamhouse.com
```

The clean URL must remain LAN / UniFi Teleport only and use the normal Caddy `private_only` gate with internal TLS.

## Current deployment status

Grafana 13.2.1 is installed and running on `docker01`.

Validated state:

```text
container                  grafana
direct port                192.168.10.135:3003
/api/health                healthy
Grafana database           ok
Prometheus datasource      provisioned successfully
anonymous access           disabled
user signup                disabled
```

Prometheus is provisioned automatically as the default datasource.

The generated initial admin credential is stored locally in:

```text
/srv/docker/monitoring/grafana/.env
```

Do not commit this file or its password.

If an admin password is ever exposed in terminal logs, chat, screenshots, or other records, rotate it using:

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

## Dashboard storage

Provisioned dashboard files will live under:

```text
/srv/docker/monitoring/grafana/dashboards
```

The first custom dashboard will be an R515-specific control plane rather than only an imported generic dashboard.

Initial sections planned:

- top-level health/status row;
- docker01 CPU, RAM, load and network;
- `/` and `/mnt/storage` capacity;
- Docker container CPU/memory/network;
- media-stack health;
- recovery-service state;
- backup age;
- SMART/disk health integration;
- later Proxmox host/VM metrics.

## Caddy

After direct Grafana validation, run:

```text
scripts/add-grafana-caddy-route.sh
```

The route is:

```caddyfile
grafana.r515.allenfamhouse.com {
    import private_only
    tls internal
    reverse_proxy 192.168.10.135:3003
}
```

The route installer follows the safe R515 Caddy workflow: backup, candidate validation, in-place overwrite to preserve the bind-mounted inode, host/container hash comparison, and `SIGUSR1` reload.

## Uptime Kuma

After the clean route is validated, add an HTTP monitor for the direct application health endpoint:

```text
http://192.168.10.135:3003/api/health
```

This checks Grafana itself rather than Caddy.

## Security

- no public WAN port for Grafana;
- no anonymous access;
- public user signup disabled;
- generated admin password stored locally in a mode-0600 `.env` file;
- private clean URL protected by Caddy `private_only`;
- secrets stay out of GitHub.
