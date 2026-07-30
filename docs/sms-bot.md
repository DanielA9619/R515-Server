# SMS Request Bot

This document tracks the local SMS-style request bot for the R515 media stack.

## Goal

Create a small request/control bot that approved users can text later through a real SMS provider.

Current local flow:

```text
Local SMS-style POST
  -> smsbot FastAPI service
  -> Seerr
  -> Radarr or Sonarr
  -> qBittorrent through Gluetun
  -> media folders
  -> Jellyfin
```

The bot is currently tested locally with curl. A real SMS provider/phone number is not connected yet.

## Current status

The local bot is installed and running in Docker on `docker01`.

Service details:

```text
Container: smsbot
Port:      5070
Health:    http://192.168.10.135:5070/health
Webhook:   http://192.168.10.135:5070/sms
App path:  /srv/docker/smsbot/app.py
Data path: /srv/docker/smsbot/data
```

Current commands tested:

```text
Help
Movie <title>
TV <title>
TV <title> season 2
Status
Downloads
Cancel
```

Validated behavior:

- `/health` returns `{"status":"ok"}`.
- `Help` returns the command list.
- `Movie Interstellar` returns numbered movie choices from Seerr.
- Replying with `1` requests the chosen movie through Seerr.
- `TV Silo season 2` returns a numbered TV result from Seerr.
- `Status` reports Seerr and qBittorrent status plus active/stalled/complete download counts.
- `Downloads` reports not-yet-complete qBittorrent downloads and filters out completed/seeding torrents.

## Docker Compose pattern

The service should stay LAN-only for now.

```yaml
smsbot:
  build: /srv/docker/smsbot
  container_name: smsbot
  restart: unless-stopped
  dns:
    - 192.168.10.135
  environment:
    - TZ=America/Denver
    - SEERR_URL=http://192.168.10.135:5055
    - SEERR_API_KEY=${SEERR_API_KEY}
    - SMSBOT_ALLOWED_SENDERS=${SMSBOT_ALLOWED_SENDERS}
    - QB_URL=${QB_URL}
    - QB_USERNAME=${QB_USERNAME}
    - QB_PASSWORD=${QB_PASSWORD}
  ports:
    - "5070:5070"
  volumes:
    - /srv/docker/smsbot/data:/app/data
```

## Environment variables

Secrets live in:

```text
/srv/docker/.env
```

Expected variables:

```env
SEERR_API_KEY=...
SMSBOT_ALLOWED_SENDERS=+15555550123,+1REALNUMBER
QB_URL=http://192.168.10.135:8080
QB_USERNAME=...
QB_PASSWORD=...
```

Do not commit `.env`, Seerr API keys, qBittorrent passwords, SMS provider tokens, or webhook signing secrets.

## Local test commands

Health check:

```bash
curl http://192.168.10.135:5070/health
```

Help:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"Help"}'
```

Movie search:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"Movie Interstellar"}'
```

Confirm first search result:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"1"}'
```

TV search:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"TV Silo season 2"}'
```

Status:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"Status"}'
```

Downloads:

```bash
curl -X POST http://192.168.10.135:5070/sms \
  -H "Content-Type: application/json" \
  -d '{"From":"+15555550123","Body":"Downloads"}'
```

## qBittorrent integration note

The bot logs into qBittorrent's Web API.

Observed successful setup behavior:

- qBittorrent API access worked after `QB_URL`, `QB_USERNAME`, and `QB_PASSWORD` were passed into the container.
- This setup returned `HTTP 204` from the qBittorrent login endpoint, so the bot treats `204 No Content` as success in addition to the older `200 Ok.` response.
- The `Downloads` command was adjusted to hide completed/seeding torrents so it only shows not-yet-complete downloads.

## Monitoring and dashboard

Recommended/confirmed monitoring:

```text
Uptime Kuma monitor:
Name: SMS Bot
Type: HTTP(s)
URL:  http://192.168.10.135:5070/health
Accepted status codes: 200-299
```

Recommended Homarr card:

```text
SMS Bot
URL: http://192.168.10.135:5070/health
```

The webhook endpoint `/sms` should not be exposed publicly until a real SMS provider, authentication checks, and remote-ingress design are finished.

## Safety rules

- Keep the bot LAN-only during local testing.
- Allow only approved sender numbers.
- Never allow arbitrary shell commands over SMS.
- Use least-privilege API keys and passwords.
- Require stronger confirmation for any future destructive commands.
- Keep audit logging in mind before adding server-control or Home Assistant-control commands.

## Next improvements

1. Confirm TV request selection submits all the way through Seerr and Sonarr.
2. Add `Recently added` using Jellyfin or filesystem/library data.
3. Improve already-requested/already-available messages from Seerr.
4. Add a simple audit log for sender, command, action, and result.
5. Choose and configure a real SMS provider/number only after local behavior is stable.
6. Back up `/srv/docker` after this working checkpoint.
