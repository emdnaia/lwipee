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

# Function to recursively shred directories from the top
recursive_shred() {
    local dir=$1
    echo "Starting shred on $dir..."
    find "$dir" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
        recursive_shred "$subdir"
    done

    # Shred all files in the current directory
    find "$dir" -type f -exec bash -c 'wipe_files "{}"' \;

    # Optionally, remove the directory itself after shredding
    if [ -z "$(find "$dir" -mindepth 1 -maxdepth 1)" ]; then
        rm -rf "$dir"
    fi
}

# Export the function so it can be used in subshells
export -f wipe_files recursive_shred

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

# Set top-level directories to shred
directories=("/etc" "/var" "/usr" "/home" "/root" "/lib" "/opt" "/mnt" "/boot" "/bin" "/sbin")

# Determine the action to take based on user input
case $choice in
    [Ee]* )
        for dir in "${directories[@]}"; do
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

# Wait for background processes to finish
wait

echo -e "\nProcessing complete!"
