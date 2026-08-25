#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../usr/bin/cachyos-bugreport.sh
source "$repo_root/usr/bin/cachyos-bugreport.sh"
original_collect_sensitive_values=$(declare -f collect_sensitive_values)

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# --- Test 1: Main redaction pass covering all sensitive data classes & edge cases ---
collect_sensitive_values() {
    cat <<'EOF'
<home-dir-redacted>	/home/alex
<username-redacted>	alex
<hostname-redacted>	cachyos
<ip-address-redacted>	192.0.2.44
<ip-address-redacted>	2001:db8::44
<mac-address-redacted>	02:11:22:33:44:55
<machine-id-redacted>	0123456789abcdef0123456789abcdef
<uuid-redacted>	ABCD-1234
<ssid-redacted>	cachyos-ap
<ssid-redacted>	Lab!
<ssid-redacted>	-foo-
<ssid-redacted>	Cafe:Lab
<ssid-redacted>	this
<usb-serial-redacted>	CURRENT-USB-123
EOF
}

LOG_FILENAME="$test_dir/report.log"
cat >"$LOG_FILENAME" <<'EOF'
uname: Linux cachyos 7.1.6-1-cachyos #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux
repo cachyos-v4 package linux-cachyos kernel 7.1.6-1-cachyos
firmware version 6.18.44.1 and bcdDevice 1.02.03.04
Linux diagnostic release 6.18.44.1
Linux kernel 6.18.44.1 loaded
Linux version is 6.18.44.1
firmware: 198.51.100.24 download mirror unavailable
firmware updater contacted 198.51.100.23
revision service endpoint 203.0.113.7
address=999.999.999.999
Host Name: cachyos
systemd: Set hostname to cachyos.
(linux-cachyos@cachyos)
home=/home/alex/config user=alex allocation=ok /home/alexander
current IPv4=192.0.2.44 current IPv6=2001:db8::44
MAC=02:11:22:33:44:55 machine=0123456789abcdef0123456789abcdef
mac:AA:BB:CC:DD:EE:FF and mac: BB:CC:DD:EE:FF:00
Mac:11:22:33:44:55:66 and wifi_mac:22:33:44:55:66:77
addr=00:11:22:33:44:55:66 and device_hwaddr=33:44:55:66:77:88
filesystem UUID=ABCD-1234 standard=123e4567-e89b-12d3-a456-426614174000 historical PARTUUID=DEAD-BEEF ID_FS_UUID=FEED-CAFE
connected to cachyos-ap; SerialNumber: CURRENT-USB-123
wifi saw Lab! Lab! nearby
wifi saw Cafe:Lab Cafe:Lab nearby
NetworkManager: association with Lab! established
wifi connected to -foo- in the office
wifi this interface connected normally
old firewall SRC=198.51.100.22 DST=2001:db8::99 MAC=00:11:22:33:44:55:66:77:88:99:aa:bb:08:00
old lease address=10.2.3.4 gateway=2001:db8::1
old wifi SSID="Old Cafe" and access point 'Older Cafe'
old device Serial Number: OLD-USB-456
machine-id=abcdefabcdefabcdefabcdefabcdefab
opened QUrl("file:///mnt/private/one") then QUrl("file:///home/alex/two") safely
contact maintainer@example.org
xhci_hcd 0000:0e:00.0: xHCI Host Controller
nvme nvme0: pci function 0000:10:00.0
amdgpu 0000:7a:00.3: amdgpu: Fetched VBIOS from VFCT
pcieport 0000:00:1c.4: AER: Corrected error received
NetworkManager: device eth0 connected; carrier on
CPU0: Thermal 100 C
AA:BB:CC:DD:EE:FF 11:22:33:44:55:66 22:33:44:55:66:77
route fe80:00:11:22:33:44:55:66 metric 100
nfs: server 198.51.100.22 not responding
Failed to connect to 10.0.0.5:8080
WireGuard endpoint 203.0.113.5:51820
invalid IP 999.999.999.999
EOF

redact >/dev/null

cat >"$test_dir/expected.log" <<'EOF'
uname: Linux <hostname-redacted> 7.1.6-1-cachyos #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux
repo cachyos-v4 package linux-cachyos kernel 7.1.6-1-cachyos
firmware version 6.18.44.1 and bcdDevice 1.02.03.04
Linux diagnostic release 6.18.44.1
Linux kernel 6.18.44.1 loaded
Linux version is 6.18.44.1
firmware: <ip-address-redacted> download mirror unavailable
firmware updater contacted <ip-address-redacted>
revision service endpoint <ip-address-redacted>
address=999.999.999.999
Host Name: <hostname-redacted>
systemd: Set hostname to <hostname-redacted>.
(linux-cachyos@<hostname-redacted>)
home=<home-dir-redacted>/config user=<username-redacted> allocation=ok /home/alexander
current IPv4=<ip-address-redacted> current IPv6=<ip-address-redacted>
MAC=<mac-address-redacted> machine=<machine-id-redacted>
mac:<mac-address-redacted> and mac: <mac-address-redacted>
Mac:<mac-address-redacted> and wifi_mac:<mac-address-redacted>
addr=00:11:22:33:44:55:66 and device_hwaddr=<mac-address-redacted>
filesystem UUID=<uuid-redacted> standard=<uuid-redacted> historical PARTUUID=<uuid-redacted> ID_FS_UUID=<uuid-redacted>
connected to <ssid-redacted>; SerialNumber: <usb-serial-redacted>
wifi saw <ssid-redacted> <ssid-redacted> nearby
wifi saw <ssid-redacted> <ssid-redacted> nearby
NetworkManager: association with <ssid-redacted> established
wifi connected to <ssid-redacted> in the office
wifi this interface connected normally
old firewall SRC=<ip-address-redacted> DST=<ip-address-redacted> MAC=<mac-address-redacted>:<mac-address-redacted>:08:00
old lease address=<ip-address-redacted> gateway=<ip-address-redacted>
old wifi SSID=<ssid-redacted> and access point '<ssid-redacted>'
old device Serial Number: <usb-serial-redacted>
machine-id=<machine-id-redacted>
opened QUrl("file://<path-redacted>") then QUrl("file://<path-redacted>") safely
contact <email-address-redacted>
xhci_hcd 0000:0e:00.0: xHCI Host Controller
nvme nvme0: pci function 0000:10:00.0
amdgpu 0000:7a:00.3: amdgpu: Fetched VBIOS from VFCT
pcieport 0000:00:1c.4: AER: Corrected error received
NetworkManager: device eth0 connected; carrier on
CPU0: Thermal 100 C
<mac-address-redacted> <mac-address-redacted> <mac-address-redacted>
route fe80:00:11:22:33:44:55:66 metric 100
nfs: server <ip-address-redacted> not responding
Failed to connect to <ip-address-redacted>
WireGuard endpoint <ip-address-redacted>
invalid IP 999.999.999.999
EOF

diff -u "$test_dir/expected.log" "$LOG_FILENAME"

# --- Test 2: Custom hostname (petes-laptop) and Avahi conflict suffix (petes-laptop-2) ---
collect_sensitive_values() {
    cat <<'EOF'
<hostname-redacted>	petes-laptop
EOF
}

LOG_FILENAME="$test_dir/hostname-custom.log"
cat >"$LOG_FILENAME" <<'EOF'
NetworkManager[689]: <info> hostname changed from "localhost" to "petes-laptop"
avahi-daemon[702]: Host name conflict, retrying with petes-laptop-2
kernel: Linux version 7.1.6-1-cachyos (linux-cachyos@petes-laptop) #1
dbus-daemon: [session uid=1000 pid=900] on petes-laptop
EOF

redact >/dev/null

cat >"$test_dir/hostname-custom-expected.log" <<'EOF'
NetworkManager[689]: <info> hostname changed from "localhost" to "<hostname-redacted>"
avahi-daemon[702]: Host name conflict, retrying with <hostname-redacted>
kernel: Linux version 7.1.6-1-cachyos (linux-cachyos@<hostname-redacted>) #1
dbus-daemon: [session uid=1000 pid=900] on <hostname-redacted>
EOF

diff -u "$test_dir/hostname-custom-expected.log" "$LOG_FILENAME"

# --- Test 3: Collection mock validations (filtering PCI BDF, date/timestamp serials, nmcli contract, user detection) ---
eval "$original_collect_sensitive_values"

# Test udevadm PCI address / generic / timestamp serial filtering
SUDO_USER=root
udevadm() {
    printf '%s\n' \
        'E: ID_SERIAL_SHORT=0000:0e:00.0' \
        'E: ID_SERIAL_SHORT=0000:10:00.0' \
        'E: ID_SERIAL_SHORT=000000000' \
        'E: ID_SERIAL_SHORT=9876543210' \
        'E: ID_SERIAL_SHORT=1234567890' \
        'E: ID_SERIAL_SHORT=0' \
        'E: ID_SERIAL_SHORT=202404073115' \
        'E: ID_SERIAL_SHORT=20231122' \
        'E: ID_SERIAL_SHORT=VALID-USB-DEVICE' \
        'E: ID_SERIAL_SHORT=SN12345678'
}
ip() { :; }
lsblk() { :; }
nmcli() { :; }

inventory=$(collect_sensitive_values)
! grep -q '0000:0e:00.0' <<<"$inventory"
! grep -q '000000000' <<<"$inventory"
! grep -q '9876543210' <<<"$inventory"
! grep -q '202404073115' <<<"$inventory"
! grep -q $'\t0$' <<<"$inventory"
grep -Fxq $'<usb-serial-redacted>\tVALID-USB-DEVICE' <<<"$inventory"
grep -Fxq $'<usb-serial-redacted>\tSN12345678' <<<"$inventory"

# Test complete nmcli contract: 7 args for list, 8 args for ssid show "$uuid"
nmcli() {
    if [ "$#" -eq 7 ] && [ "${1:-}" = "--terse" ] && [ "${2:-}" = "--escape" ] && [ "${3:-}" = "no" ] && [ "${4:-}" = "--fields" ] && [ "${5:-}" = "TYPE,UUID,NAME" ] && [ "${6:-}" = "connection" ] && [ "${7:-}" = "show" ]; then
        printf '%s\n' '802-11-wireless:uuid-123:My Profile 1'
    elif [ "$#" -eq 8 ] && [ "${1:-}" = "--terse" ] && [ "${2:-}" = "--escape" ] && [ "${3:-}" = "no" ] && [ "${4:-}" = "-g" ] && [ "${5:-}" = "802-11-wireless.ssid" ] && [ "${6:-}" = "connection" ] && [ "${7:-}" = "show" ] && [ "${8:-}" = "uuid-123" ]; then
        printf '%s\n' 'Cafe:Lab'
    else
        echo "nmcli mock failed: unexpected arguments ($#): $*" >&2
        return 1
    fi
}
inventory=$(collect_sensitive_values)
grep -Fxq $'<ssid-redacted>\tMy Profile 1' <<<"$inventory"
grep -Fxq $'<ssid-redacted>\tCafe:Lab' <<<"$inventory"

# Test user detection fallback with PKEXEC_UID
unset SUDO_USER || true
export PKEXEC_UID=1000
id() {
    if [ "$1" = "-nu" ] && [ "$2" = "1000" ]; then
        printf '%s\n' 'pkexec_user'
    fi
}
getent() {
    if [ "$1" = "passwd" ] && [ "$2" = "pkexec_user" ]; then
        printf '%s\n' 'pkexec_user:x:1000:1000::/home/pkexec_user:/bin/bash'
    fi
}
inventory=$(collect_sensitive_values)
grep -Fxq $'<username-redacted>\tpkexec_user' <<<"$inventory"
grep -Fxq $'<home-dir-redacted>\t/home/pkexec_user' <<<"$inventory"

# --- Test 4: EXIT cleanup trap behavior ---
trap_test_file="$test_dir/preexisting.log"
touch "$trap_test_file"

# Scenario A: Non-zero exit before bugreport() starts (CLEANUP_ON_ERROR=0) must preserve existing file
LOG_FILENAME="$trap_test_file"
CLEANUP_ON_ERROR=0
(
    exit_with_error() { return 1; }
    exit_with_error || cleanup
) || true
[ -f "$trap_test_file" ]

# Scenario B: Non-zero exit after bugreport() creates unredacted report (CLEANUP_ON_ERROR=1) must remove it
LOG_FILENAME="$trap_test_file"
CLEANUP_ON_ERROR=1
(
    exit_with_error() { return 1; }
    exit_with_error || cleanup
) || true
[ ! -f "$trap_test_file" ]

# Scenario C: Successful redact() disarms CLEANUP_ON_ERROR
LOG_FILENAME="$test_dir/redacted_ok.log"
printf '%s\n' 'some diagnostic line' >"$LOG_FILENAME"
collect_sensitive_values() { :; }
CLEANUP_ON_ERROR=1
redact >/dev/null
[ "$CLEANUP_ON_ERROR" -eq 0 ]
(
    exit_with_error() { return 1; }
    exit_with_error || cleanup
) || true
[ -f "$LOG_FILENAME" ]

# --- Test 5: Empty inventory degradation ---
collect_sensitive_values() { :; }
LOG_FILENAME="$test_dir/empty-inventory.log"
printf '%s\n' 'plain diagnostic text remains intact' >"$LOG_FILENAME"
redact >/dev/null
grep -Fxq 'plain diagnostic text remains intact' "$LOG_FILENAME"

# --- Test 6: Collector failures must fail closed before upload can be reached ---
for failure_mode in immediate partial; do
    LOG_FILENAME="$test_dir/collector-$failure_mode.log"
    printf 'private WIFI-%s\n' "$failure_mode" >"$LOG_FILENAME"

    if [ "$failure_mode" = immediate ]; then
        collect_sensitive_values() { return 1; }
    else
        collect_sensitive_values() {
            printf '%s\t%s\n' '<ssid-redacted>' WIFI-PARTIAL
            return 1
        }
    fi

    CLEANUP_ON_ERROR=1
    if ( trap cleanup EXIT; redact >/dev/null ); then
        echo "collector failure unexpectedly succeeded: $failure_mode" >&2
        exit 1
    fi
    [ ! -f "$LOG_FILENAME" ]
done

# --- Test 7: Ignored final candidates do not make valid emission fail ---
if ! emitted_values=$(printf '%s\n' valid-value no '' | emit_sensitive_values '<test-redacted>'); then
    echo 'emit_sensitive_values rejected ignored final candidates' >&2
    exit 1
fi
grep -Fxq $'<test-redacted>\tvalid-value' <<<"$emitted_values"
[ "$(printf '%s\n' "$emitted_values" | wc -l)" -eq 1 ]

# --- Test 8: Successful collection and redaction still work after fail-closed checks ---
collect_sensitive_values() {
    printf '%s\t%s\n' '<ssid-redacted>' WIFI-SUCCESS
}
LOG_FILENAME="$test_dir/success-after-failure.log"
printf 'connected to WIFI-SUCCESS\n' >"$LOG_FILENAME"
CLEANUP_ON_ERROR=1
redact >/dev/null
grep -Fxq 'connected to <ssid-redacted>' "$LOG_FILENAME"
[ "$CLEANUP_ON_ERROR" -eq 0 ]

printf '%s\n' 'bugreport redaction tests: PASS'
