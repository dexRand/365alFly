#!/usr/bin/env bash
# Probes the host for pptx-open (WinApps + FreeRDP) requirements.
# Portable: run on WSL2 or native Linux. Exits 1 if hard requirements are missing.
set -u

PASS_COUNT=0
FAIL_COUNT=0

req()  { local name="$1" status="$2" detail="${3:-}"; if [ "$status" = "OK" ]; then PASS_COUNT=$((PASS_COUNT+1)); printf "  [OK]   %-28s %s\n" "$name" "$detail"; else FAIL_COUNT=$((FAIL_COUNT+1)); printf "  [FAIL] %-28s %s\n" "$name" "$detail"; fi; }
chk()  { local name="$1" cmd="$2" status="FAIL" detail="missing"; if command -v "$cmd" >/dev/null 2>&1; then status="OK"; detail="$(command -v "$cmd")"; fi; req "$name" "$status" "$detail"; }

echo "=== Host ==="
grep -E "^(PRETTY_NAME|VERSION_ID)=" /etc/os-release 2>/dev/null
uname -srmo
if grep -qi microsoft /proc/version 2>/dev/null; then echo "platform: WSL"; else echo "platform: native Linux"; fi

echo
echo "=== Resources ==="
echo "  CPUs:    $(nproc)"
free -h 2>/dev/null | awk '/Mem:/{printf "  RAM:     %s total, %s avail\n", $2, $7}'
df -h / 2>/dev/null | awk 'NR==2{printf "  Disk:    %s free on /\n", $4}'

echo
echo "=== Virtualization ==="
if [ -e /dev/kvm ]; then req "KVM (/dev/kvm)" OK "device present"; else req "KVM (/dev/kvm)" FAIL "device missing: nested virtualization needed"; fi

echo
echo "=== Windows/containers backends (uno dei seguenti) ==="
chk "docker" docker
chk "podman" podman
chk "virsh (libvirt)" virsh
chk "qemu-system-x86_64" qemu-system-x86_64

echo
echo "=== FreeRDP client ==="
chk "xfreerdp" xfreerdp
chk "xfreerdp3" xfreerdp3

echo
echo "=== Display ==="
echo "  DISPLAY=${DISPLAY:-unset}"
echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
if [ -d /mnt/wslg ]; then echo "  WSLg: present"; fi

echo
echo "=== Tools ==="
for t in wget curl git unzip shellcheck bats; do chk "$t" "$t"; done

echo
echo "=== Summary ==="
echo "  PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] && echo "  Result: environment OK" || echo "  Result: missing items above"
exit 0