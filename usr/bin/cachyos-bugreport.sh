#!/usr/bin/env bash
# CachyOS bug reporting shell script.  This shell
# script will generate a log file named "cachyos-bug-report.log".

set -euo pipefail

LOG_FILENAME="${LOG_FILENAME:-"cachyos-bugreport.log"}"
OLD_LOG_FILENAME=cachyos-bugreport.log.old

ask_yes_no(){
    local question="${1}"
    local answer=""
    while ! printf '%s' "${answer}" | grep -q '^\([Yy]\(es\)\?\|[Nn]\(o\)\?\)$'; do
        printf '%s' "${question} [Y]es/[N]o: "
        read -r answer
    done

    if printf '%s' "${answer}" | grep -q '^[Nn]\(o\)\?$'; then
        return 1
    fi
}

check_root(){
    # Check that we are root, required for dmesg
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: Please run $(basename "$0") as root." >&2
        exit 1
    fi
}


# move any old log file
check_oldlog() {
    if [ -f "$LOG_FILENAME" ]; then
        mv "$LOG_FILENAME" "$OLD_LOG_FILENAME"
    fi
}


check_wpermission() {
    if ! touch "$LOG_FILENAME" 2>/dev/null; then
        cat << EOF >&2

ERROR: Working directory is not writable; please cd to a directory
       where you have write permission so that the $LOG_FILENAME
       file can be written.

EOF
        exit 1
    fi
}

get_installed_packages() {
    if [ -e /var/lib/pacman/sync/cachyos-v4.db ]; then
        pacman -Ss | grep --color=never "^cachyos-v4/.*\[installed\]" || true
    elif [ -e /var/lib/pacman/sync/cachyos-v3.db ]; then
        pacman -Ss | grep --color=never "^cachyos-v3/.*\[installed\]" || true
    elif [ -e /var/lib/pacman/sync/cachyos-znver4.db ]; then
        pacman -Ss | grep --color=never "^cachyos-znver4/.*\[installed\]" || true
    else
        echo "znver4, v4 or v3 repositories are not used"
    fi
}

bugreport() {
    echo "Starting with bugreport"

    cat << EOF >"$LOG_FILENAME"
____________________________________________

Start of CachyOS bug report log file. Please send this report,
along with a description of your bug, to CachyOS.

Date: $(date)
uname: $(uname -a)
cmdline: $(cat /proc/cmdline)

____________________________________________
Getting Hardware Information

$(inxi -Farz)
____________________________________________
Getting Scheduler information

sched-ext:
$(grep -R "" /sys/kernel/sched_ext/ 2>/dev/null || echo "sched_ext not available")

$(journalctl --output cat -k | grep -i scheduler || true)

____________________________________________

dmesg

$(dmesg)

____________________________________________
journalctl of current boot

$(journalctl --no-hostname -b -p 4..1)
____________________________________________
journalctl of previous boot

$(journalctl --no-hostname -b -1 -p 4..1 2>/dev/null || echo "No previous boot log available")
____________________________________________

Installed packages

$(get_installed_packages)
--------------------------------------------
EOF
}

CLEANUP_ON_ERROR=0

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ "${CLEANUP_ON_ERROR:-0}" -eq 1 ] && [ -n "${LOG_FILENAME:-}" ] && [ -f "$LOG_FILENAME" ]; then
        rm -f "$LOG_FILENAME" 2>/dev/null || true
    fi
}

emit_sensitive_values() {
    local replacement="$1"
    local value

    while IFS= read -r value; do
        if [ -n "$value" ] && [ "${#value}" -ge 3 ]; then
            printf '%s\t%s\n' "$replacement" "$value"
        fi
    done
}

collect_sensitive_values() {
    local real_user="${SUDO_USER:-}"
    local address_file
    local machine_id_file
    local hn

    if [ -z "$real_user" ] && [ -n "${PKEXEC_UID:-}" ]; then
        real_user="$(id -nu "$PKEXEC_UID" 2>/dev/null || true)"
    fi
    if [ -z "$real_user" ]; then
        real_user="$(logname 2>/dev/null || true)"
    fi

    if [ -n "$real_user" ] && [ "$real_user" != "root" ]; then
        { getent passwd "$real_user" 2>/dev/null || true; } |
            cut -d: -f6 |
            emit_sensitive_values '<home-dir-redacted>'
        printf '%s\n' "$real_user" | emit_sensitive_values '<username-redacted>'
    fi

    hn="$(uname -n 2>/dev/null || hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || true)"
    if [ -n "$hn" ] && [ "$hn" != "localhost" ] && [ "$hn" != "(none)" ] && [ "${#hn}" -ge 2 ]; then
        printf '%s\n' "$hn" | emit_sensitive_values '<hostname-redacted>'
    fi

    if command -v ip >/dev/null; then
        { ip -o address show 2>/dev/null || true; } |
            awk '$2 != "lo" && ($3 == "inet" || $3 == "inet6") {sub(/\/.*/, "", $4); print $4}' |
            emit_sensitive_values '<ip-address-redacted>'
    fi

    for address_file in /sys/class/net/*/address; do
        if [ -r "$address_file" ]; then
            sed '/^00:00:00:00:00:00$/d' "$address_file"
        fi
    done | emit_sensitive_values '<mac-address-redacted>'

    for machine_id_file in /etc/machine-id /var/lib/dbus/machine-id; do
        if [ -r "$machine_id_file" ]; then
            sed -n '1p' "$machine_id_file"
        fi
    done | sort -u | emit_sensitive_values '<machine-id-redacted>'

    if command -v lsblk >/dev/null; then
        { lsblk -rno UUID 2>/dev/null || true; } | emit_sensitive_values '<uuid-redacted>'
    fi

    if command -v nmcli >/dev/null; then
        local uuid name ssid
        while IFS=: read -r uuid name; do
            [ -n "$name" ] && [ "${#name}" -ge 3 ] && printf '%s\n' "$name"
            if [ -n "$uuid" ]; then
                ssid="$(nmcli --terse --escape no -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)"
                [ -n "$ssid" ] && [ "${#ssid}" -ge 3 ] && printf '%s\n' "$ssid"
            fi
        done < <({ nmcli --terse --escape no --fields TYPE,UUID,NAME connection show 2>/dev/null || true; } | sed -nE 's/^(802-11-wireless|wifi)://p') |
            grep -Ev '^(the|and|for|are|but|not|you|all|any|can|had|her|was|one|our|out|day|get|has|him|his|how|man|new|now|old|see|two|way|who|boy|did|its|let|put|say|she|too|use|off|yes|true|set|raw|end|low|top|bad|run|try|ask)$' -i |
            emit_sensitive_values '<ssid-redacted>'
    fi

    if command -v udevadm >/dev/null; then
        { udevadm info --export-db 2>/dev/null || true; } |
            sed -n 's/^E: ID_SERIAL_SHORT=//p' |
            grep -Ev '^[0-9a-fA-F]{2,4}:|\.[0-9a-fA-F]$|^0+$|^[0-9]{1,3}$|^(.)\1+$|^123456|^987654|^012345|^(19|20)[0-9]{6,}$' |
            emit_sensitive_values '<usb-serial-redacted>'
    fi
}

sed_escape() {
    printf '%s\n' "$1" | sed 's/[][\\.^$*+?(){}|#]/\\&/g'
}

redact() {
    echo "Redacting personal information..."

    local sed_args=()
    local inventory
    local replacement
    local value

    if ! inventory="$(collect_sensitive_values)"; then
        echo "ERROR: could not enumerate values to redact; refusing to continue." >&2
        return 1
    fi

    while IFS=$'\t' read -r replacement value; do
        [ -n "$value" ] || continue
        [ "${#value}" -ge 3 ] || continue
        if [ "$replacement" = '<username-redacted>' ]; then
            sed_args+=(-e "s#\\b$(sed_escape "$value")\\b#${replacement}#g")
        elif [ "$replacement" = '<hostname-redacted>' ]; then
            sed_args+=(-e "s#(^|[^a-zA-Z0-9_/-])$(sed_escape "$value")(-[0-9]+)?([^a-zA-Z0-9_/-]|$)#\\1${replacement}\\3#g" \
                       -e "s#(^|[^a-zA-Z0-9_/-])$(sed_escape "$value")(-[0-9]+)?([^a-zA-Z0-9_/-]|$)#\\1${replacement}\\3#g")
        elif [ "$replacement" = '<ssid-redacted>' ]; then
            if printf '%s\n' "$value" | grep -Eqi '^(the|and|for|are|but|not|you|all|any|can|had|her|was|one|our|out|day|get|has|him|his|how|man|new|now|old|see|two|way|who|boy|did|its|let|put|say|she|too|use|off|yes|true|set|raw|end|low|top|bad|run|try|ask|this)$'; then
                sed_args+=(-e "s#((SSID|ssid|access point|connected to|connecting to|associated with|association with|network|connection|saw)[=:[:space:]]+['\"]?)$(sed_escape "$value")(['\"]?([^a-zA-Z0-9]|$))#\\1${replacement}\\3#gI" \
                           -e "s#((SSID|ssid|access point|connected to|connecting to|associated with|association with|network|connection|saw)[=:[:space:]]+['\"]?)$(sed_escape "$value")(['\"]?([^a-zA-Z0-9]|$))#\\1${replacement}\\3#gI")
            else
                sed_args+=(-e "/(SSID|ssid|access point|connected to|associated with|association with|connection|NetworkManager|wlan[0-9]|wifi|Wi-Fi)/I s#(^|[^a-zA-Z0-9])$(sed_escape "$value")([^a-zA-Z0-9]|$)#\\1${replacement}\\2#g" \
                           -e "/(SSID|ssid|access point|connected to|associated with|association with|connection|NetworkManager|wlan[0-9]|wifi|Wi-Fi)/I s#(^|[^a-zA-Z0-9])$(sed_escape "$value")([^a-zA-Z0-9]|$)#\\1${replacement}\\2#g")
            fi
        elif [ "$replacement" = '<home-dir-redacted>' ]; then
            sed_args+=(-e "s#$(sed_escape "$value")\\b#${replacement}#g")
        else
            sed_args+=(-e "s#\\b$(sed_escape "$value")\\b#${replacement}#g")
        fi
    done <<<"$inventory"

    # Hostnames occur in fixed report fields. Avoid replacing generic hostnames in
    # useful strings such as linux-cachyos and cachyos-v4.
    sed_args+=(-e 's#^(uname: [^[:space:]]+[[:space:]]+)[^[:space:]]+#\1<hostname-redacted>#')
    sed_args+=(-e 's#((hostname|Host Name)[=:][[:space:]]*)[^[:space:]]+#\1<hostname-redacted>#g')
    sed_args+=(-e 's#((Set hostname to|hostname set to)[[:space:]]+)[^[:space:].]+#\1<hostname-redacted>#gI')

    # Structured network fields with shared valid IPv4 octet semantics
    sed_args+=(-e 's#\b(SRC|DST)=[^[:space:]]+#\1=<ip-address-redacted>#g')
    sed_args+=(-e 's#\b(([a-zA-Z0-9_]*(ip_address|address|gateway|nameserver|endpoint|server|host|mirror|contacted|firmware))[=:][>[:space:]]*)(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}(:[0-9]+)?#\1<ip-address-redacted>#gI')
    sed_args+=(-e 's#\b(contacted|endpoint|server|mirror)[[:space:]]+(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}(:[0-9]+)?#\1 <ip-address-redacted>#gI')
    sed_args+=(-e 's#((ip_address|address|gateway|nameserver|endpoint)[=:][>[:space:]]*)[0-9A-Fa-f]*:[0-9A-Fa-f:.%]+#\1<ip-address-redacted>#g')
    sed_args+=(-e 's#\b(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}:[0-9]{2,5}\b#<ip-address-redacted>#g')

    # Standalone valid IPv4 address redaction preserving diagnostic dotted releases/versions
    sed_args+=(-e '/\b(version|release|kernel|bcdDevice|revision)([[:space:]]+(is|version|release|tag|of))?[[:space:]:=]+[0-9]+(\.[0-9]+){3}\b/I! s#\b(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}\b#<ip-address-redacted>#g')

    # Wi-Fi and USB fields
    sed_args+=(-e "s#((SSID|ssid)[=:][[:space:]]*)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)#\\1<ssid-redacted>#g")
    sed_args+=(-e "s#((access point)[[:space:]]+)'[^']*'#\\1'<ssid-redacted>'#g")
    sed_args+=(-e 's#((SerialNumber|Serial Number|ID_SERIAL_SHORT)[=:][[:space:]]*)[^[:space:]]+#\1<usb-serial-redacted>#g')
    sed_args+=(-e 's#((machine-id|Machine ID)[=:][[:space:]]*)[[:xdigit:]]{32}#\1<machine-id-redacted>#g')

    # MAC addresses: explicit Netfilter MAC= chains + labeled fields (with case/prefix support) + standalone MACs (preserving longer colon-hex/IPv6)
    sed_args+=(-e 's#\bMAC=([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}:([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}#MAC=<mac-address-redacted>:<mac-address-redacted>#g')
    sed_args+=(-e 's#(^|[^0-9A-Fa-f:])([a-zA-Z0-9_]*(MAC|mac|HWaddr|hwaddr|ether|address|addr)[=:][[:space:]]*)([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)#\1\2<mac-address-redacted>\5#gI')
    sed_args+=(-e 's#(^|[^0-9A-Fa-f:])([a-zA-Z0-9_]*(MAC|mac|HWaddr|hwaddr|ether|address|addr)[=:][[:space:]]*)([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)#\1\2<mac-address-redacted>\5#gI')
    sed_args+=(-e 's#(^|[^0-9A-Fa-f:])([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)#\1<mac-address-redacted>\3#g')
    sed_args+=(-e 's#(^|[^0-9A-Fa-f:])([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)#\1<mac-address-redacted>\3#g')

    # UUIDs, URLs, Email
    sed_args+=(-e 's#\b[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}\b#<uuid-redacted>#g')
    sed_args+=(-e 's#(^|[^a-zA-Z0-9])((PART|ID_FS_)?UUID=)[0-9A-Fa-f-]+#\1\2<uuid-redacted>#g')
    sed_args+=(-e 's#(/dev/disk/by-uuid/)[^[:space:]]+#\1<uuid-redacted>#g')
    sed_args+=(-e 's#"file://[^"]*"#"file://<path-redacted>"#g')
    sed_args+=(-e 's#[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}#<email-address-redacted>#g')

    # Single sed pass for all substitutions
    sed -Ei "${sed_args[@]}" "$LOG_FILENAME"
    CLEANUP_ON_ERROR=0
}

upload() {
    if ask_yes_no 'Do you want to upload this log to https://paste.cachyos.org?'; then
        echo "Uploading Log"
        paste-cachyos "$LOG_FILENAME"
    else
        echo "Not uploading Log"
    fi

}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    trap cleanup EXIT
    check_root
    check_oldlog
    check_wpermission
    CLEANUP_ON_ERROR=1
    bugreport
    redact
    upload
fi
