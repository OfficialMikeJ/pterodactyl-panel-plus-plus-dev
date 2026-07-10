#!/bin/bash
set -euo pipefail

#############################################################################
#  Touch Down Hosting — Storage Attach Agent (Linux / BSD / NAS)            #
#                                                                           #
#  Run on any machine to register its storage with your panel:              #
#                                                                           #
#    curl -sSL __PANEL_URL__/storage/attach.sh | sudo bash -s -- \          #
#      --token=YOUR_ATTACH_TOKEN                                            #
#                                                                           #
#  Auto-detects:                                                            #
#   - extra local disks / partitions that are not mounted                   #
#   - cloud block-storage volumes (Linode, Hetzner, OVH, DigitalOcean)      #
#   - the NAS operating system it is running on:                            #
#       HexOS, TrueNAS SCALE, TrueNAS CORE (FreeBSD), OpenMediaVault,       #
#       CasaOS, Unraid, Ubuntu Server (and other Linux distros)             #
#   - or, when no spare devices exist, registers the whole machine as a     #
#     dedicated storage server with its free capacity                       #
#                                                                           #
#  Windows Server storage does not use this agent - register the machine's #
#  SMB share directly on the panel's Storage page instead.                  #
#                                                                           #
#  Safe by default: DETECTS AND REPORTS ONLY. Nothing is written to disk    #
#  unless you opt in:                                                       #
#    --mount    mount detected, already-formatted volumes                   #
#    --format   format UNFORMATTED volumes as ext4, then mount them         #
#    --mode=server   skip device detection, register as storage server      #
#                                                                           #
#  On NAS systems (TrueNAS, Unraid, OMV, ...) the agent never formats or    #
#  mounts — the NAS manages its own pools; it registers capacity instead.  #
#############################################################################

PANEL_URL="__PANEL_URL__"
TOKEN=""
DO_MOUNT="no"
DO_FORMAT="no"
MODE="auto"

ORANGE='\033[38;5;208m'; GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
log()   { echo -e "${ORANGE}[Touch Down]${RESET} $1"; }
ok()    { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
fail()  { echo -e "${RED}[ERROR ]${RESET} $1" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --token=*) TOKEN="${arg#*=}" ;;
    --mount) DO_MOUNT="yes" ;;
    --format) DO_FORMAT="yes"; DO_MOUNT="yes" ;;
    --mode=server) MODE="server" ;;
    *) fail "Unknown option: $arg" ;;
  esac
done

[ -n "$TOKEN" ] || fail "Missing --token=... (generate one on the panel's Storage page)"
[ "$(id -u)" -eq 0 ] || fail "Run as root (sudo)."
command -v curl >/dev/null || fail "curl is required."

KERNEL="$(uname -s 2>/dev/null || echo unknown)"

# ── NAS operating system detection ─────────────────────────────────────────
detect_nas_os() {
  if [ "$KERNEL" = "FreeBSD" ]; then
    if [ -f /etc/version ] && grep -qi 'truenas\|freenas' /etc/version 2>/dev/null; then
      echo "truenas-core"
    else
      echo "freebsd"
    fi
    return
  fi

  # Unraid ships a version marker in /etc.
  if [ -f /etc/unraid-version ]; then
    echo "unraid"
    return
  fi

  # TrueNAS SCALE (and HexOS, which is built on top of SCALE) ship midclt.
  if command -v midclt >/dev/null 2>&1 && [ -f /etc/version ]; then
    if grep -qi hexos /etc/version 2>/dev/null || [ -f /etc/hexos-release ] || [ -d /usr/local/hexos ]; then
      echo "hexos"
    else
      echo "truenas-scale"
    fi
    return
  fi

  if [ -f /etc/default/openmediavault ]; then
    echo "openmediavault"
    return
  fi

  if [ -x /usr/bin/casaos ] || [ -d /etc/casaos ] || [ -f /usr/lib/systemd/system/casaos.service ] \
    || [ -f /etc/systemd/system/casaos.service ]; then
    echo "casaos"
    return
  fi

  if [ -r /etc/os-release ]; then
    local os_id
    os_id="$(. /etc/os-release && echo "${ID:-linux}")"
    if [ "$os_id" = "ubuntu" ]; then
      echo "ubuntu-server"
    else
      echo "$os_id"
    fi
    return
  fi

  echo "linux"
}

# ── Host provider detection (DMI vendor strings; Linux only) ───────────────
detect_host_provider() {
  local vendor=""
  [ -r /sys/class/dmi/id/sys_vendor ] && vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
  case "${vendor,,}" in
    *digitalocean*) echo "digitalocean" ;;
    *hetzner*) echo "hetzner" ;;
    *linode*|*akamai*) echo "linode" ;;
    *ovh*) echo "ovh" ;;
    *) echo "local" ;;
  esac
}

# ── Per-device provider detection (cloud volumes have branded by-id links) ─
device_provider() {
  local dev="$1" link
  for link in /dev/disk/by-id/*; do
    [ -e "$link" ] || continue
    if [ "$(readlink -f "$link")" = "/dev/$dev" ]; then
      case "$link" in
        *DO_Volume*) echo "digitalocean"; return ;;
        *HC_Volume*) echo "hetzner"; return ;;
        *Linode_Volume*|*linode*volume*) echo "linode"; return ;;
        *OVH*) echo "ovh"; return ;;
      esac
    fi
  done
  detect_host_provider
}

NAS_OS="$(detect_nas_os)"
HOST_PROVIDER="$(detect_host_provider)"
HOSTNAME_STR="$(hostname)"
IP_STR="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
[ -z "$IP_STR" ] && IP_STR="$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}' || true)"

log "Panel:    ${PANEL_URL}"
log "Host:     ${HOSTNAME_STR} (${IP_STR:-no ip})"
log "System:   ${NAS_OS} (${KERNEL})"
log "Provider: ${HOST_PROVIDER}"

# NAS platforms manage their own disks/pools — never touch them, register
# capacity instead. Plain Linux distros keep full device handling.
case "$NAS_OS" in
  truenas-core|truenas-scale|hexos|unraid|openmediavault|casaos)
    if [ "$DO_MOUNT" = "yes" ] || [ "$DO_FORMAT" = "yes" ]; then
      log "Detected a NAS OS (${NAS_OS}) — ignoring --mount/--format; the NAS manages its own storage."
      DO_MOUNT="no"; DO_FORMAT="no"
    fi
    MODE="server"
    ;;
esac

[ "$KERNEL" = "FreeBSD" ] && MODE="server"

volumes_json=""
count=0

if [ "$MODE" != "server" ]; then
  command -v lsblk >/dev/null || fail "lsblk is required for device detection (or re-run with --mode=server)."
  log "Scanning for unmounted disks and cloud volumes..."

  root_disk="$(lsblk -nro NAME,MOUNTPOINT | awk '$2=="/" {print $1}' | head -1 || true)"
  root_parent=""
  [ -n "$root_disk" ] && root_parent="$(lsblk -nro PKNAME "/dev/${root_disk}" 2>/dev/null | head -1 || true)"

  while read -r name type size; do
    [ "$type" = "disk" ] || continue
    [ "$name" = "$root_disk" ] && continue
    [ -n "$root_parent" ] && [ "$name" = "$root_parent" ] && continue

    # Skip the disk if it (or any of its partitions) is already mounted.
    if lsblk -nro MOUNTPOINT "/dev/$name" | grep -q '.'; then
      continue
    fi

    fstype=""
    command -v blkid >/dev/null 2>&1 && fstype="$(blkid -o value -s TYPE "/dev/$name" 2>/dev/null || true)"
    provider="$(device_provider "$name")"
    mountpoint=""

    if [ -z "$fstype" ] && [ "$DO_FORMAT" = "yes" ]; then
      command -v mkfs.ext4 >/dev/null || fail "mkfs.ext4 not available on this system."
      log "Formatting /dev/$name as ext4..."
      mkfs.ext4 -F -q "/dev/$name"
      fstype="ext4"
    fi

    if [ -n "$fstype" ] && [ "$DO_MOUNT" = "yes" ]; then
      count_dirs=0
      while [ -d "/mnt/touchdown-storage-$count_dirs" ]; do count_dirs=$((count_dirs + 1)); done
      mountpoint="/mnt/touchdown-storage-$count_dirs"
      mkdir -p "$mountpoint"
      mount "/dev/$name" "$mountpoint"
      uuid="$(blkid -o value -s UUID "/dev/$name")"
      if ! grep -q "$uuid" /etc/fstab; then
        echo "UUID=$uuid $mountpoint $fstype defaults,nofail 0 2" >> /etc/fstab
      fi
      ok "Mounted /dev/$name at $mountpoint"
    fi

    [ $count -gt 0 ] && volumes_json+=","
    volumes_json+="{\"device\":\"/dev/$name\",\"size_bytes\":$size,\"fstype\":\"${fstype:-unformatted}\",\"mount\":\"${mountpoint}\",\"provider\":\"$provider\"}"
    count=$((count + 1))
    ok "Detected /dev/$name ($(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes"), ${fstype:-unformatted}, $provider)"
  done < <(lsblk -bdnro NAME,TYPE,SIZE)
fi

if [ $count -eq 0 ]; then
  MODE_STR="storage-server"
  log "Registering this machine as a dedicated storage server (${NAS_OS})."
  # Portable across GNU coreutils and BSD: df -k reports 1K blocks.
  read -r total_bytes free_bytes < <(df -k / | tail -1 | awk '{print $2 * 1024, $4 * 1024}')
else
  MODE_STR="local-device"
  total_bytes=0
  free_bytes=0
fi

payload="{\"token\":\"$TOKEN\",\"hostname\":\"$HOSTNAME_STR\",\"ip\":\"$IP_STR\",\"provider\":\"$HOST_PROVIDER\",\"nas_os\":\"$NAS_OS\",\"mode\":\"$MODE_STR\",\"total_bytes\":${total_bytes:-0},\"free_bytes\":${free_bytes:-0},\"volumes\":[${volumes_json}]}"

log "Reporting to panel..."
response="$(curl -sS -X POST "$PANEL_URL/api/storage/ingest" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$payload")" || fail "Could not reach the panel at $PANEL_URL"

if echo "$response" | grep -q '"ok":true'; then
  ok "Storage registered with Touch Down Hosting! Check the panel's Storage page."
  [ $count -gt 0 ] && [ "$DO_MOUNT" = "no" ] && log "Detected volumes were NOT mounted (report-only). Re-run with --mount (or --format for blank disks) to mount them."
else
  fail "Panel rejected the report: $response"
fi
