#!/bin/bash
set -euo pipefail

#############################################################################
#  Touch Down Hosting — Storage Attach Agent                                #
#                                                                           #
#  Run on any Linux machine to register its storage with your panel:       #
#                                                                           #
#    curl -sSL __PANEL_URL__/storage/attach.sh | sudo bash -s -- \          #
#      --token=YOUR_ATTACH_TOKEN                                            #
#                                                                           #
#  Auto-detects:                                                            #
#   - extra local disks / partitions that are not mounted                   #
#   - cloud block-storage volumes (Linode, Hetzner, OVH, DigitalOcean)      #
#   - or, when no spare devices exist, registers the whole machine as a     #
#     dedicated storage server with its free capacity                       #
#                                                                           #
#  Safe by default: DETECTS AND REPORTS ONLY. Nothing is written to disk    #
#  unless you opt in:                                                       #
#    --mount    mount detected, already-formatted volumes                   #
#    --format   format UNFORMATTED volumes as ext4, then mount them         #
#    --mode=server   skip device detection, register as storage server      #
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
command -v lsblk >/dev/null || fail "lsblk is required."

# ── Host provider detection (DMI vendor strings) ───────────────────────────
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

# ── Find the disk that holds / so we never touch it ────────────────────────
root_disk="$(lsblk -nro NAME,MOUNTPOINT | awk '$2=="/" {print $1}' | head -1 || true)"
root_parent=""
[ -n "$root_disk" ] && root_parent="$(lsblk -nro PKNAME "/dev/${root_disk}" 2>/dev/null | head -1 || true)"

HOST_PROVIDER="$(detect_host_provider)"
HOSTNAME_STR="$(hostname)"
IP_STR="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '')"

log "Panel:    ${PANEL_URL}"
log "Host:     ${HOSTNAME_STR} (${IP_STR:-no ip})"
log "Provider: ${HOST_PROVIDER}"

volumes_json=""
count=0

if [ "$MODE" != "server" ]; then
  log "Scanning for unmounted disks and cloud volumes..."

  while read -r name type size; do
    [ "$type" = "disk" ] || continue
    [ "$name" = "$root_disk" ] && continue
    [ -n "$root_parent" ] && [ "$name" = "$root_parent" ] && continue

    # Skip the disk if it (or any of its partitions) is already mounted.
    if lsblk -nro MOUNTPOINT "/dev/$name" | grep -q '.'; then
      continue
    fi

    fstype="$(blkid -o value -s TYPE "/dev/$name" 2>/dev/null || true)"
    provider="$(device_provider "$name")"
    mountpoint=""

    if [ -z "$fstype" ] && [ "$DO_FORMAT" = "yes" ]; then
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
  log "No spare devices found — registering this machine as a dedicated storage server."
  read -r total_bytes free_bytes < <(df -B1 --output=size,avail / | tail -1)
else
  MODE_STR="local-device"
  total_bytes=0
  free_bytes=0
fi

payload="{\"token\":\"$TOKEN\",\"hostname\":\"$HOSTNAME_STR\",\"ip\":\"$IP_STR\",\"provider\":\"$HOST_PROVIDER\",\"mode\":\"$MODE_STR\",\"total_bytes\":${total_bytes:-0},\"free_bytes\":${free_bytes:-0},\"volumes\":[${volumes_json}]}"

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
