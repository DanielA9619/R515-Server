# R515 Alerting

This is the notification layer for the R515 observability/control-plane stack.

## Architecture

```text
R515 custom metrics + node_exporter + cAdvisor
                |
                v
           Prometheus
                |
                v
         Alertmanager
          192.168.10.135:9093
                |
                v
        hosted ntfy.sh topic
                |
                v
           phone app
```

The initial delivery path intentionally uses the hosted `ntfy.sh` service instead of exposing another self-hosted service to the public Internet. This keeps the R515 inbound attack surface unchanged while still allowing alerts to reach the phone when away from home.

A later self-hosted ntfy deployment remains possible. For iOS instant notifications, self-hosted ntfy requires `upstream-base-url: https://ntfy.sh`, and the phone must still be able to reach the self-hosted server to fetch the real message contents.

## Versions

- Alertmanager: `v0.34.0`
- Prometheus: existing `v3.13.3`
- ntfy delivery: hosted `https://ntfy.sh`

## Current deployment status

Alertmanager is installed and running on `docker01`.

Validated state:

```text
Alertmanager              ready on 192.168.10.135:9093
Prometheus discovery      working
R515 alert rules          loaded
manual test alert         accepted by Alertmanager
ntfy topic                generated and stored locally
```

Prometheus reports the active Alertmanager endpoint as:

```text
http://192.168.10.135:9093/api/v2/alerts
```

The remaining end-to-end validation step is subscribing the phone to the private ntfy topic and confirming a fresh test alert is delivered.

## Installer

```text
scripts/install-alertmanager-ntfy.sh
```

Run on `docker01` as root.

The installer:

1. verifies Prometheus and port `9093`;
2. generates a long random ntfy topic and stores it locally at `/srv/docker/monitoring/alerting/ntfy-topic.txt` with mode `0600`;
3. deploys Alertmanager as a separate Compose stack under `/srv/docker/monitoring/alerting`;
4. configures Alertmanager to publish JSON webhooks to `https://ntfy.sh/<topic>?template=alertmanager`;
5. installs the R515 Prometheus alert rules;
6. patches the existing Prometheus config and Compose mount without replacing unrelated content;
7. validates Alertmanager and Prometheus configs before restart/recreate;
8. verifies Prometheus discovers Alertmanager and loads the rules;
9. submits a short-lived test alert through Alertmanager.

The ntfy topic is effectively a secret and must not be committed to GitHub or pasted into public logs.

### First-install permission issue found during deployment

The first live run exposed a shell-permission bug: `umask 077` was set while generating the topic and remained active for the rest of that shell. That caused the subsequently created `alertmanager.yml` to be mode `0600`, so the non-root `amtool` process inside the validation container could not read it and reported:

```text
open /etc/alertmanager/alertmanager.yml: permission denied
```

The live recovery was to set the Alertmanager config and Compose file to mode `0644`, validate with `amtool`, then rerun the installer. The second run completed successfully. Future installer revisions should scope the restrictive umask only to topic-file creation or explicitly set config-file modes before container validation.

## Alert rules

Initial rules include:

- `/mnt/storage` not mounted;
- `/mnt/storage` not writable;
- Gluetun unhealthy;
- Byparr `/health` failing;
- post-boot recovery failed;
- Byparr recovery failed;
- config backup missing;
- config backup older than 7 days;
- config backup older than 14 days;
- custom R515 metrics missing;
- custom R515 metrics stale for more than 3 minutes;
- docker01 node_exporter down;
- docker01 cAdvisor down;
- `/mnt/storage` below 200 GiB free.

## Alertmanager routing

Alertmanager groups by alert name and severity with:

```text
group_wait:      20s
group_interval:  5m
repeat_interval: 4h
```

Resolved alerts are also sent to ntfy.

## ntfy phone setup

After deployment, reveal the topic locally only when adding the phone subscription:

```bash
cat /srv/docker/monitoring/alerting/ntfy-topic.txt
```

In the ntfy app:

```text
Server: https://ntfy.sh
Topic:  <value from ntfy-topic.txt>
```

Because the hosted ntfy service is outbound-only from the R515, no new WAN port forward or public R515 hostname is required.

## Uptime Kuma

Add an HTTP monitor for Alertmanager itself:

```text
http://192.168.10.135:9093/-/ready
```

Recommended settings:

```text
name:     Alertmanager
interval: 60 seconds
retries:  2
```

Kuma remains useful for checking the alerting service itself, because Prometheus cannot notify through Alertmanager if Alertmanager is unavailable.

## Security

- keep port `9093` LAN/Teleport only;
- do not publish the random ntfy topic;
- do not commit `/srv/docker/monitoring/alerting/ntfy-topic.txt`;
- do not add a WAN forward for Alertmanager;
- the initial design deliberately avoids exposing a self-hosted ntfy endpoint publicly.
