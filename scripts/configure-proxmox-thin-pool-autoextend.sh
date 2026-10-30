#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE_DIR="/etc/lvm/profile"
PROFILE_NAME="r515-thin-autoextend"
PROFILE_FILE="${PROFILE_DIR}/${PROFILE_NAME}.profile"
POOL="pve/data"

section(){ printf '\n=== %s ===\n' "$1"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on the Proxmox host."
command -v pveversion >/dev/null || fail "This is intended for the Proxmox host."
command -v lvs >/dev/null || fail "lvs missing"
command -v lvchange >/dev/null || fail "lvchange missing"

section "PRECHECK"

lvs "$POOL" -o vg_name,lv_name,lv_size,data_percent,metadata_percent,seg_monitor --noheadings

VG_FREE_BYTES="$(vgs pve --noheadings --units b --nosuffix -o vg_free | tr -d ' ')"
python3 - "$VG_FREE_BYTES" <<'PY'
import sys
free=float(sys.argv[1])
print(f"VG free space: {free/1024**3:.2f} GiB")
if free < 8*1024**3:
    raise SystemExit("ERROR: less than 8 GiB is free in VG pve; refusing to configure automatic extension")
PY

section "ENABLE LVM MONITORING"

systemctl enable --now lvm2-monitor.service
lvchange --monitor y "$POOL"

section "INSTALL PER-POOL AUTOEXTEND PROFILE"

mkdir -p "$PROFILE_DIR"
if [ -f "$PROFILE_FILE" ]; then
  cp -a "$PROFILE_FILE" "${PROFILE_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
fi

cat > "$PROFILE_FILE" <<'EOF'
activation {
    thin_pool_autoextend_threshold=90
    thin_pool_autoextend_percent=5
}
EOF

chmod 0644 "$PROFILE_FILE"
lvchange --metadataprofile "$PROFILE_NAME" "$POOL"

section "VERIFY"

systemctl is-active --quiet lvm2-monitor.service ||
  fail "lvm2-monitor is not active"

lvs "$POOL" \
  -o vg_name,lv_name,lv_size,data_percent,metadata_percent,seg_monitor,metadata_profile

echo
echo "Effective profile:"
cat "$PROFILE_FILE"

echo
echo "Current VG free:"
vgs pve -o vg_name,vg_size,vg_free

echo
echo "Policy: when pve/data reaches 90%, dmeventd may extend it by 5% if VG free extents remain."
echo "The Prometheus local-lvm 85%/95% alerts remain the primary notification layer."
echo
echo "=== PROXMOX THIN-POOL AUTOEXTEND CONFIGURED ==="
