#!/usr/bin/env bash
# CachyOS bug reporting shell script.  This shell
# script will generate a log file named "cachyos-bug-report.log".

LOG_FILENAME="${LOG_FILENAME:-"cachyos-bugreport.log"}"
OLD_LOG_FILENAME=cachyos-bugreport.log.old

ask_yes_no(){
    local question="${1}"
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
        pacman -Ss | grep --color=never "^cachyos-v4/.*\[installed\]"
    elif [ -e /var/lib/pacman/sync/cachyos-v3.db ]; then
        pacman -Ss | grep --color=never "^cachyos-v3/.*\[installed\]"
    elif [ -e /var/lib/pacman/sync/cachyos-znver4.db ]; then
        pacman -Ss | grep --color=never "^cachyos-znver4/.*\[installed\]"
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

____________________________________________
Getting Hardware Information

$(inxi -F)
____________________________________________
Getting Scheduler information

sched-ext:
$(grep -R "" /sys/kernel/sched_ext/)

$(journalctl --output cat -k | grep -i scheduler)

____________________________________________

dmesg

$(dmesg)

____________________________________________
journalctl of current boot

$(journalctl -b -p 4..1)
____________________________________________

Installed packages

$(get_installed_packages)
--------------------------------------------
EOF
}

upload() {
    if ask_yes_no 'Do you want to upload this log to https://paste.cachyos.org?'; then
        echo "Uploading Log"
        paste-cachyos "$LOG_FILENAME"
    else
        echo "Not uploading Log"
    fi

}

check_root
check_oldlog
check_wpermission
bugreport
upload
