#!/bin/bash

# Function to check for the presence of critical binaries
check_binaries() {
    command -v shred >/dev/null 2>&1 && SHRED_PRESENT=true || SHRED_PRESENT=false
    command -v gpg >/dev/null 2>&1 && GPG_PRESENT=true || GPG_PRESENT=false
    command -v dd >/dev/null 2>&1 && DD_PRESENT=true || DD_PRESENT=false
    command -v rm >/dev/null 2>&1 && RM_PRESENT=true || RM_PRESENT=false
    command -v nohup >/dev/null 2>&1 && NOHUP_PRESENT=true || NOHUP_PRESENT=false
    command -v tail >/dev/null 2>&1 && TAIL_PRESENT=true || TAIL_PRESENT=false
    command -v find >/dev/null 2>&1 && FIND_PRESENT=true || FIND_PRESENT=false
    command -v which >/dev/null 2>&1 && WHICH_PRESENT=true || WHICH_PRESENT=false
}

# Function to create necessary log files
prepare_logs() {
    touch nohup.out remaining_files.log
    chmod 600 nohup.out remaining_files.log
}

# Function to create a simple progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$(( current * 100 / total ))
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))

    printf "\r["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] %d%%" "$percent"
}

# Function to wipe using efficient shredding
wipe_files() {
    if $SHRED_PRESENT; then
        echo "Using shred on $1..."
        shred -uzv "$1" >> remaining_files.log 2>&1 || {
            echo "Shred failed for $1. Using rm..."
            rm -f "$1" >> remaining_files.log 2>&1
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

# Function to encrypt files before wiping
encrypt_files() {
    if $GPG_PRESENT; then
        echo "Using gpg on $1..."
        gpg --yes --batch --passphrase "$PASSPHRASE" -c "$1"
    else
        echo "gpg not found, skipping encryption on $1."
    fi
}

# Function to recursively shred directories from the top
recursive_shred() {
    local dir=$1
    echo "Starting shred on $dir..."
    if $FIND_PRESENT; then
        find "$dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
            recursive_shred "$subdir"
        done
        find "$dir" -type f -exec bash -c 'wipe_files "{}"' \;
    else
        echo "find command not available. Skipping shredding of $dir."
    fi
    # Optionally, remove the directory itself after shredding
    if [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        rm -rf "$dir"
    fi
}

# Export the function so it can be used in subshells
export -f wipe_files recursive_shred encrypt_files

# Function to handle errors and initiate DD fallback
dd_fallback() {
    echo "Critical failure encountered. Initiating DD fallback to wipe remaining data..."
    local drives=$(lsblk -nd --output NAME)
    for drive in $drives; do
        echo "Wiping /dev/$drive with DD..."
        sudo dd if=/dev/urandom of=/dev/$drive bs=1M status=progress || {
            echo "Failed to wipe /dev/$drive with DD. Continuing to the next available drive..."
        }
    done
    echo "DD fallback complete. System will now shut down."
    sudo shutdown -h now
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

# Set top-level directories to shred in the optimal order
directories=(
    "/var/lib" "/var/backups" "/var/mail"
    "/srv" "/opt" "/mnt" "/home"
    "/etc" "/boot" # Delay /boot shredding
    "/root" # Delay /root shredding 
    "/bin" "/sbin" "/usr/bin" "/usr/sbin" # Delay shredding of essential bins
    "/lib" "/lib64" "/usr/lib" "/usr/lib64" # Do this last
)

# Check if dd is functional before proceeding
if ! $DD_PRESENT; then
    echo "DD not found or non-functional. Triggering DD fallback immediately."
    dd_fallback
fi

# Determine the action to take based on user input
case $choice in
    [Ee]* )
        for dir in "${directories[@]}"; do
            find "$dir" -type f -exec bash -c 'encrypt_files "{}"' \;
            recursive_shred "$dir"
        done
        ;;
    [Ww]* )
        for dir in "${directories[@]}"; do
            recursive_shred "$dir"
        done
        ;;
    [Bb]* )
        for dir in "${directories[@]}"; do
            find "$dir" -type f -exec bash -c 'encrypt_files "{}"' \;
            recursive_shred "$dir"
        done
        ;;
    * )
        echo "Please choose (E) encrypt, (W) wipe, or (B) both."
        exit 1
        ;;
esac

# Log progress
log_progress

# Final check if DD fallback is needed
if ! $FIND_PRESENT || ! $WHICH_PRESENT; then
    dd_fallback
fi

echo -e "\nProcessing complete!"
