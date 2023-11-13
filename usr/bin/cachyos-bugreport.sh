#!/bin/bash

# CachyOS bug reporting shell script.  This shell
# script will generate a log file named "cachyos-bug-report.log".

LOG_FILENAME=cachyos-bugreport.log
OLD_LOG_FILENAME=cachyos-bugreport.log.old

ask_yes_no(){
    answer="${1}"
    question="${2}"
    while ! printf '%s' "${answer}" | grep -q '^\([Yy]\(es\)\?\|[Nn]\(o\)\?\)$'; do
        printf '%s' "${question} [Y]es/[N]o: "
        read -r answer
    done

    if printf '%s' "${answer}" | grep -q '^[Nn]\(o\)\?$'; then
        return 1
    fi
}

print_error(){
    message="${1}"
    printf '%s\n' "Error: ${message}" >&2
}

check_root(){
    # check that we are root, required for dmesg
    if [ $(id -u) -ne 0 ]; then
        echo "ERROR: Please run $(basename "$0") as root."
        exit 1
    fi
}


# move any old log file
check_oldlog() {
    if [ -f $LOG_FILENAME ]; then
        mv $LOG_FILENAME $OLD_LOG_FILENAME
    fi
}


check_wpermission() {
    touch $LOG_FILENAME 2> /dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: Working directory is not writable; please cd to a directory"
        echo "       where you have write permission so that the $LOG_FILENAME"
        echo "       file can be written."
        echo
        exit 1
    fi
}

bugreport() {
    echo "Starting with bugreport"

    # print prologue to the log file
    echo "____________________________________________"                    >> $LOG_FILENAME
    echo ""                                                                >> $LOG_FILENAME
    echo "Start of CachyOS bug report log file. Please send this report,"  >> $LOG_FILENAME
    echo "along with a description of your bug, to CachyOS."               >> $LOG_FILENAME
    echo ""                                                                >> $LOG_FILENAME
    echo ""                                                                >> $LOG_FILENAME
    echo "Date: $(date)"                                                   >> $LOG_FILENAME
    echo "uname: $(uname -a)"                                              >> $LOG_FILENAME
    echo ""                                                                >> $LOG_FILENAME

    echo "Getting Hardware Information"
    inxi -F >> $LOG_FILENAME

    echo "dmesg"
    dmesg >> $LOG_FILENAME

    echo "journalctl of current boot"
    journalctl -b -p 4..1 >> $LOG_FILENAME
}

upload() {
    if ask_yes_no "${upload_log}" 'Do you want to upload this log to https://paste.cachyos.org?'; then
        upload_log='yes'
        echo "Uploading Log"
        cat $LOG_FILENAME | paste-cachyos
    else
        upload_log='no'
        echo "Not uploading Log"
    fi

}

check_root
check_oldlog
check_wpermission
bugreport
upload
