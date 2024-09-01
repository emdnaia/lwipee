#!/bin/bash

read -p "Do you want to (E)ncrypt, (W)ipe, or (B)oth? " choice

case $choice in
    [Ee]* ) 
        read -s -p "Enter passphrase for encryption: " PASSPHRASE
        echo
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
        -exec timeout 10s bash -c 'echo "$PASSPHRASE" | gpg --yes --batch --passphrase-fd 0 -c {}' \; || true && \
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
        -exec timeout 10s shred -uz -n 1 {} + || true && \
        tail -f nohup.out remaining_files.log &
        ;;
    [Bb]* )
        read -s -p "Enter passphrase for encryption: " PASSPHRASE
        echo
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
        -exec timeout 10s bash -c 'echo "$PASSPHRASE" | gpg --yes --batch --passphrase-fd 0 -c {}' \; || true \
        -exec timeout 10s shred -uz -n 1 {} + || true && \
        tail -f nohup.out remaining_files.log &
        ;;
    * )
        echo "Please choose (E) encrypt, (W) wipe, or (B) both."
        ;;
esac
