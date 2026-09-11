#!/usr/bin/env bash
set -u

cd /srv/docker 2>/dev/null || true

section() {
  printf '\n\n=== %s ===\n' "$1"
}

section "R515 OBSERVABILITY PREFLIGHT"
date
hostnamectl 2>/dev/null | sed -n '1,8p' || hostname

section "RECOVERY SERVICES"
sudo systemctl status r515-postboot-recovery.service r515-byparr-recovery.service --no-pager -l 2>/dev/null | sed -n '1,80p' || true

section "STORAGE MOUNT"
findmnt -T /mnt/storage || true
df -hT / /srv/docker /mnt/storage 2>/dev/null || true

section "BLOCK DEVICES"
lsblk -o NAME,KNAME,PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,TRAN 2>/dev/null || lsblk

section "SMART VISIBILITY"
if command -v smartctl >/dev/null 2>&1; then
  echo "smartctl: $(command -v smartctl)"
  sudo smartctl --scan-open || true

  STORAGE_SOURCE=$(findmnt -n -o SOURCE -T /mnt/storage 2>/dev/null || true)
  echo "Storage source: ${STORAGE_SOURCE:-unknown}"

  if [ -n "${STORAGE_SOURCE:-}" ]; then
    PARENT=$(lsblk -n -o PKNAME "$STORAGE_SOURCE" 2>/dev/null | head -n1 || true)
    if [ -n "$PARENT" ]; then
      STORAGE_DISK="/dev/$PARENT"
    else
      STORAGE_DISK="$STORAGE_SOURCE"
    fi

    echo "Likely storage disk for SMART: $STORAGE_DISK"
    sudo smartctl -a "$STORAGE_DISK" 2>&1 | sed -n '1,140p' || true
  fi
else
  echo "smartctl is NOT installed. No package was installed by this preflight."
fi

section "HOST RESOURCES"
free -h || true
nproc || true
uptime || true

section "NVIDIA"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.total,memory.used --format=csv,noheader 2>/dev/null || nvidia-smi
else
  echo "nvidia-smi not found"
fi

section "DOCKER STATUS"
if command -v docker >/dev/null 2>&1; then
  sudo docker compose ps 2>/dev/null || sudo docker ps
  echo
  sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}' 2>/dev/null || true
else
  echo "docker not found"
fi

section "LISTENING PORTS"
sudo ss -lntup 2>/dev/null | sed -n '1,220p' || ss -lnt 2>/dev/null || true

section "BACKUP SCRIPT"
if [ -x /srv/docker/scripts/backup-r515-configs.sh ]; then
  echo "PASS: /srv/docker/scripts/backup-r515-configs.sh exists and is executable"
else
  echo "WARN: backup script missing or not executable"
fi

section "PREFLIGHT COMPLETE"
echo "This script made no configuration changes."
