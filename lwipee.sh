#!/bin/bash

# Function to check for the presence of critical binaries
check_binaries() {
    command -v shred >/dev/null 2>&1 && SHRED_PRESENT=true || SHRED_PRESENT=false
    command -v gpg >/dev/null 2>&1 && GPG_PRESENT=true || GPG_PRESENT=false
    command -v dd >/dev/null 2>&1 && DD_PRESENT=true || DD_PRESENT=false
    command -v rm >/dev/null 2>&1 && RM_PRESENT=true || RM_PRESENT=false
    command -v nohup >/dev/null 2>&1 && NOHUP_PRESENT=true || NOHUP_PRESENT=false
    command -v tail >/dev/null 2>&1 && TAIL_PRESENT=true || TAIL_PRESENT=false
}

# Function to create necessary log files
prepare_logs() {
    touch nohup.out remaining_files.log
    chmod 600 nohup.out remaining_files.log
}

# Function to wipe using efficient shredding
wipe_files() {
    if $SHRED_PRESENT; then
        echo "Using shred on $1..."
        shred -uzv "$1" >> remaining_files.log 2>&1
    elif $DD_PRESENT; then
        echo "shred not found, using dd on $1..."
        dd if=/dev/urandom of="$1" bs=1M status=progress
    elif $RM_PRESENT; then
        echo "shred and dd not found, using rm on $1..."
        rm -f "$1"
    else
        echo "No suitable tool found for wiping."
    fi
}

# Function to encrypt using available tools
encrypt_files() {
    if $GPG_PRESENT; then
        echo "Using gpg on $1..."
        timeout 10s gpg --yes --batch --passphrase "$PASSPHRASE" -c "$1"
    else
        echo "gpg not found, skipping encryption."
    fi
}

# Function to process files based on user choice
process_files() {
    local action=$1
    export -f "$action" # Export the function so that it is available in subshells
    if $NOHUP_PRESENT; then
        nohup sudo find /tmp /var/log /var/tmp /home /var/cache /opt /usr/local /var/lib \
        /usr/bin /usr/sbin /lib /lib64 /etc /boot /bin /sbin /mnt \
        -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -type f \
        ! -name "$(which shred)" \
        ! -name "$(which gpg)" \
        ! -name "$(which bash)" \
        ! -name "$(which sh)" \
        ! -name "$(which find)" \
        ! -name "$(which timeout)" \
        ! -name "$(which nohup)" \
        ! -name "$(which sudo)" \
        ! -name "$(which rm)" \
        ! -name "$(which mv)" \
        ! -name "$(which ls)" \
        -exec bash -c "$action \"{}\"" \; >> remaining_files.log 2>&1 &
    else
        echo "nohup not found, running without it..."
        sudo find /tmp /var/log /var/tmp /home /var/cache /opt /usr/local /var/lib \
        /usr/bin /usr/sbin /lib /lib64 /etc /boot /bin /sbin /mnt \
        -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -type f \
        ! -name "$(which shred)" \
        ! -name "$(which gpg)" \
        ! -name "$(which bash)" \
        ! -name "$(which sh)" \
        ! -name "$(which find)" \
        ! -name "$(which timeout)" \
        ! -name "$(which nohup)" \
        ! -name "$(which sudo)" \
        ! -name "$(which rm)" \
        ! -name "$(which mv)" \
        ! -name "$(which ls)" \
        -exec bash -c "$action \"{}\"" \; >> remaining_files.log 2>&1
    fi
}

# Function to log progress if possible
log_progress() {
    if $TAIL_PRESENT; then
        tail -f nohup.out remaining_files.log &
    else
        echo "tail not found, unable to log progress."
    fi
}

# Initial binary check
check_binaries

# Create log files
prepare_logs

# Prompt user for the desired action
read -p "Do you want to (E)ncrypt, (W)ipe, or (B)oth? " choice

# Prompt for passphrase if encryption is selected
if [[ $choice =~ [EeBb] ]]; then
    read -s -p "Enter passphrase for encryption: " PASSPHRASE
    echo
fi

# Determine the action to take based on user input
case $choice in
    [Ee]* )
        process_files "encrypt_files"
        ;;
    [Ww]* )
        process_files "wipe_files"
        ;;
    [Bb]* )
        process_files "encrypt_files"
        process_files "wipe_files"
        ;;
    * )
        echo "Please choose (E) encrypt, (W) wipe, or (B) both."
        exit 1
        ;;
esac

# Log progress
log_progress

# Wait for background processes to finish
wait

echo "Process complete."
