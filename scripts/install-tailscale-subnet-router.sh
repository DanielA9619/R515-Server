#!/usr/bin/env bash
set -Eeuo pipefail

# R515 Tailscale subnet-router installer.
# Run as root on the Proxmox host (r515).
# Creates/reuses a small unprivileged Debian LXC, passes /dev/net/tun,
# installs Tailscale, advertises the home LAN, and runs validation checks.

TS_HOSTNAME="r515-tailscale"
LAN_CIDR="192.168.10.0/24"
PROXMOX_IP="192.168.10.50"
DOCKER01_IP="192.168.10.135"
GATEWAY_IP="192.168.10.1"
BRIDGE="vmbr0"
TEMPLATE_STORAGE="local"
ROOTFS_STORAGE="local-lvm"
DISK_GB="4"
MEMORY_MB="512"
SWAP_MB="256"
CORES="1"
TIMEZONE="America/Denver"

section() {
  printf '\n=== %s ===\n' "$1"
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

warn() {
  echo "WARNING: $*"
}

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  fail "run this script as root on the Proxmox host."
fi

section "R515 TAILSCALE SUBNET ROUTER"

command -v pveversion >/dev/null || fail "pveversion not found; this must run on the Proxmox host."
command -v pct >/dev/null || fail "pct not found."
command -v pveam >/dev/null || fail "pveam not found."
command -v pvesm >/dev/null || fail "pvesm not found."
command -v pvesh >/dev/null || fail "pvesh not found."
command -v ip >/dev/null || fail "iproute2 tools not found on the host."

HOSTNAME_NOW="$(hostname)"
echo "Host:    ${HOSTNAME_NOW}"
echo "Proxmox: $(pveversion | head -n 1)"
echo "LAN:     ${LAN_CIDR}"
echo "Bridge:  ${BRIDGE}"

[ -e /dev/net/tun ] || modprobe tun || true
[ -c /dev/net/tun ] || fail "/dev/net/tun is not available on the Proxmox host."
pass "host TUN device available."

ip link show "$BRIDGE" >/dev/null 2>&1 || fail "bridge ${BRIDGE} does not exist."
pass "bridge ${BRIDGE} exists."

if ! ip -4 addr show dev "$BRIDGE" | grep -qF "${PROXMOX_IP}/"; then
  warn "${PROXMOX_IP} was not found on ${BRIDGE}; verify the bridge before relying on subnet routing."
else
  pass "Proxmox LAN address is present on ${BRIDGE}."
fi

if ! pvesm status | awk -v s="$TEMPLATE_STORAGE" 'NR > 1 && $1 == s && $3 == "active" {found=1} END {exit !found}'; then
  fail "template storage ${TEMPLATE_STORAGE} is not active."
fi

if ! pvesm status | awk -v s="$ROOTFS_STORAGE" 'NR > 1 && $1 == s && $3 == "active" {found=1} END {exit !found}'; then
  fail "rootfs storage ${ROOTFS_STORAGE} is not active."
fi

pass "required Proxmox storage targets are active."

section "LOCATE OR CREATE LXC"

EXISTING_CONF="$(grep -l "^hostname: ${TS_HOSTNAME}$" /etc/pve/lxc/*.conf 2>/dev/null | head -n 1 || true)"

if [ -n "$EXISTING_CONF" ]; then
  CTID="$(basename "$EXISTING_CONF" .conf)"
  echo "INFO: existing ${TS_HOSTNAME} container found as CT ${CTID}; reusing it."
else
  CTID="$(pvesh get /cluster/nextid)"
  [ -n "$CTID" ] || fail "could not obtain the next Proxmox CT ID."

  echo "Using new CT ID: ${CTID}"

  section "DOWNLOAD DEBIAN TEMPLATE"
  pveam update >/dev/null

  TEMPLATE="$(pveam available --section system | awk '$2 ~ /^debian-13-standard_/ {print $2}' | sort -V | tail -n 1)"
  if [ -z "$TEMPLATE" ]; then
    warn "Debian 13 template not found; falling back to Debian 12."
    TEMPLATE="$(pveam available --section system | awk '$2 ~ /^debian-12-standard_/ {print $2}' | sort -V | tail -n 1)"
  fi
  [ -n "$TEMPLATE" ] || fail "no supported Debian standard LXC template was found."

  TEMPLATE_VOL="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"
  if pveam list "$TEMPLATE_STORAGE" | awk '{print $1}' | grep -qxF "$TEMPLATE_VOL"; then
    echo "INFO: template already downloaded: ${TEMPLATE_VOL}"
  else
    echo "Downloading ${TEMPLATE}..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
  fi

  section "CREATE UNPRIVILEGED LXC"
  pct create "$CTID" "$TEMPLATE_VOL" \
    --hostname "$TS_HOSTNAME" \
    --ostype debian \
    --unprivileged 1 \
    --cores "$CORES" \
    --memory "$MEMORY_MB" \
    --swap "$SWAP_MB" \
    --rootfs "${ROOTFS_STORAGE}:${DISK_GB}" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp,type=veth" \
    --nameserver "1.1.1.1" \
    --features "keyctl=1,nesting=1" \
    --onboot 1 \
    --startup "order=10,up=15,down=60"

  pass "created unprivileged CT ${CTID}."
fi

section "CONFIGURE TUN + STARTUP"

pct set "$CTID" --features "keyctl=1,nesting=1" >/dev/null
pct set "$CTID" --dev0 /dev/net/tun >/dev/null
pct set "$CTID" --onboot 1 --startup "order=10,up=15,down=60" >/dev/null

if pct status "$CTID" | grep -q 'status: running'; then
  if ! pct exec "$CTID" -- test -c /dev/net/tun >/dev/null 2>&1; then
    echo "Restarting CT ${CTID} so /dev/net/tun passthrough takes effect..."
    pct stop "$CTID"
    pct start "$CTID"
  fi
else
  pct start "$CTID"
fi

for _ in $(seq 1 60); do
  if pct exec "$CTID" -- true >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

pct exec "$CTID" -- true >/dev/null 2>&1 || fail "CT ${CTID} did not become responsive."
pct exec "$CTID" -- test -c /dev/net/tun || fail "/dev/net/tun is not visible inside CT ${CTID}."
pass "TUN device is available inside CT ${CTID}."

section "WAIT FOR DHCP"

CT_IP=""
for _ in $(seq 1 60); do
  CT_IP="$(pct exec "$CTID" -- bash -lc "ip -4 -o addr show dev eth0 2>/dev/null | awk '{print \\$4}' | cut -d/ -f1 | head -n1" 2>/dev/null || true)"
  if [ -n "$CT_IP" ]; then
    break
  fi
  sleep 2
done

[ -n "$CT_IP" ] || fail "CT ${CTID} did not receive a DHCP address on ${BRIDGE}."
echo "CT LAN IP: ${CT_IP}"
pass "DHCP networking is up."

section "INSTALL + CONFIGURE TAILSCALE"

pct exec "$CTID" -- env TIMEZONE="$TIMEZONE" LAN_CIDR="$LAN_CIDR" bash -s <<'INNER'
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl jq iproute2 iputils-ping

timedatectl set-timezone "$TIMEZONE" || true

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "INFO: Tailscale already installed: $(tailscale version | head -n1)"
fi

systemctl enable --now tailscaled

cat > /etc/sysctl.d/99-tailscale.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

sysctl -p /etc/sysctl.d/99-tailscale.conf

test "$(sysctl -n net.ipv4.ip_forward)" = "1"
test "$(sysctl -n net.ipv6.conf.all.forwarding)" = "1"

echo "PASS: Tailscale installed and IP forwarding enabled."
INNER

section "TAILSCALE LOGIN"

STATE="$(pct exec "$CTID" -- bash -lc "tailscale status --json 2>/dev/null | jq -r '.BackendState // empty'" 2>/dev/null || true)"

if [ "$STATE" != "Running" ]; then
  echo "A Tailscale login URL should appear below."
  echo "Open it in your browser and sign in to the tailnet you want to use."
  echo
  pct exec "$CTID" -- tailscale up \
    --hostname="$TS_HOSTNAME" \
    --accept-dns=false \
    --advertise-routes="$LAN_CIDR"
else
  echo "INFO: Tailscale is already authenticated."
fi

pct exec "$CTID" -- tailscale set \
  --hostname="$TS_HOSTNAME" \
  --accept-dns=false \
  --advertise-routes="$LAN_CIDR"

STATE="$(pct exec "$CTID" -- bash -lc "tailscale status --json | jq -r '.BackendState'" 2>/dev/null || true)"
[ "$STATE" = "Running" ] || fail "Tailscale is not in Running state after authentication."
pass "Tailscale is connected."

section "APPROVE SUBNET ROUTE"

echo "Manual approval is required once in the Tailscale admin console:"
echo "  1. Open Machines."
echo "  2. Select ${TS_HOSTNAME}."
echo "  3. Open route settings / subnet routes."
echo "  4. Approve ${LAN_CIDR}."
echo
echo "This router intentionally does NOT advertise itself as an exit node."
echo
read -rp "After approving ${LAN_CIDR}, press Enter to run validation tests... " _

section "VALIDATION"

FAILS=0

test_cmd() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$label"
  else
    echo "FAIL: $label"
    FAILS=$((FAILS + 1))
  fi
}

test_cmd "CT is running" bash -lc "pct status '$CTID' | grep -q 'status: running'"
test_cmd "TUN is available in the CT" pct exec "$CTID" -- test -c /dev/net/tun
test_cmd "tailscaled is active" pct exec "$CTID" -- systemctl is-active --quiet tailscaled
test_cmd "Tailscale backend is Running" pct exec "$CTID" -- bash -lc "tailscale status --json | jq -e '.BackendState == \"Running\"'"
test_cmd "IPv4 forwarding is enabled" pct exec "$CTID" -- bash -lc "test \"\$(sysctl -n net.ipv4.ip_forward)\" = 1"
test_cmd "IPv6 forwarding is enabled" pct exec "$CTID" -- bash -lc "test \"\$(sysctl -n net.ipv6.conf.all.forwarding)\" = 1"
test_cmd "LAN route is being advertised" pct exec "$CTID" -- bash -lc "tailscale debug prefs | grep -qF '$LAN_CIDR'"
test_cmd "No exit-node default route is advertised" pct exec "$CTID" -- bash -lc "! tailscale debug prefs | grep -Eq '0\\.0\\.0\\.0/0|::/0'"
test_cmd "LAN gateway is reachable" pct exec "$CTID" -- ping -c 1 -W 3 "$GATEWAY_IP"
test_cmd "Proxmox UI is reachable from the router" pct exec "$CTID" -- curl -kfsS --max-time 5 "https://${PROXMOX_IP}:8006/"
test_cmd "docker01 Prometheus is reachable from the router" pct exec "$CTID" -- curl -fsS --max-time 5 "http://${DOCKER01_IP}:9090/-/ready"

TS_IP="$(pct exec "$CTID" -- tailscale ip -4 2>/dev/null | head -n1 || true)"
MAC="$(pct config "$CTID" | sed -n 's/^net0:.*hwaddr=\([^,]*\).*/\1/p')"

section "STATUS"

echo "CT ID:          ${CTID}"
echo "Hostname:       ${TS_HOSTNAME}"
echo "LAN IP:         ${CT_IP}"
echo "LAN MAC:        ${MAC:-unknown}"
echo "Tailscale IP:   ${TS_IP:-unknown}"
echo "Advertised LAN: ${LAN_CIDR}"
echo "Exit node:      no"
echo "On boot:        enabled"
echo
pct exec "$CTID" -- tailscale status || true

echo
if [ "$FAILS" -eq 0 ]; then
  echo "=== TAILSCALE SUBNET ROUTER SERVER-SIDE SETUP COMPLETE ==="
  echo
  echo "All server-side validation checks passed."
  echo "Next: install Tailscale on the PC/phone, sign into the same tailnet,"
  echo "then test ${PROXMOX_IP}:8006 from outside the home LAN."
else
  echo "=== SETUP COMPLETED WITH ${FAILS} FAILED CHECK(S) ==="
  echo "Review the failed checks above before relying on Tailscale for remote access."
  exit 1
fi
