#!/bin/bash

set -e

# === FUNCTIONS ===

# Detect Boot Mode
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI mode detected."
        BOOT_MODE="UEFI"
    else
        echo "BIOS mode detected."
        BOOT_MODE="BIOS"
    fi
}

# Detect Available Drives
list_drives() {
    echo "Available drives:"
    lsblk -d -n -e 7,11 -o NAME,SIZE,MODEL | while read -r name size model; do
        echo "/dev/$name - $size ($model)"
    done
}

# Prompt for Drive Selection
select_drive() {
    echo "Enter the drive to install Arch on (e.g., /dev/sda):"
    read -rp "> " INSTALL_DRIVE
    if [ ! -b "$INSTALL_DRIVE" ]; then
        echo "Invalid drive selected."
        exit 1
    fi
}

# Prompt for /home Configuration
configure_home_partition() {
    echo "Configure /home partition:"
    echo "1) Use remaining space on main drive"
    echo "2) Specify fixed size on main drive"
    echo "3) Use another drive if available"
    read -rp "Select option [1-3]: " HOME_OPTION

    case "$HOME_OPTION" in
        1)
            HOME_MODE="remaining"
            ;;
        2)
            read -rp "Enter fixed size for /home (e.g., 20G): " HOME_SIZE
            HOME_MODE="fixed"
            ;;
        3)
            echo "Looking for additional drives..."
            OTHER_DRIVES=$(lsblk -d -n -e 7,11 -o NAME | grep -v "$(basename "$INSTALL_DRIVE")")
            if [ -z "$OTHER_DRIVES" ]; then
                echo "No other drives found. Falling back to main drive with remaining space."
                HOME_MODE="remaining"
            else
                echo "Available secondary drives:"
                echo "$OTHER_DRIVES" | while read -r name; do
                    lsblk -d -n -o NAME,SIZE,MODEL "/dev/$name"
                done
                read -rp "Select drive for /home (e.g., /dev/sdb): " HOME_DRIVE
                if [ ! -b "$HOME_DRIVE" ]; then
                    echo "Invalid secondary drive. Exiting."
                    exit 1
                fi
                HOME_MODE="other"
            fi
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
}

# Prompt for Swap Size
configure_swap() {
    read -rp "Enter swap partition size (e.g., 2G): " SWAP_SIZE
    if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[MG]$ ]]; then
        echo "Invalid size format. Use number followed by M or G."
        exit 1
    fi
}

# === MAIN ===
clear
echo "=== Arch Linux Install Script: Disk Setup Phase ==="
detect_boot_mode
echo
list_drives
echo
select_drive
echo
configure_home_partition
echo
configure_swap

# Summary
echo
echo "=== Summary ==="
echo "Boot Mode      : $BOOT_MODE"
echo "Install Drive  : $INSTALL_DRIVE"
echo "Swap Size      : $SWAP_SIZE"
if [ "$HOME_MODE" = "fixed" ]; then
    echo "/home Mode     : Fixed size ($HOME_SIZE)"
elif [ "$HOME_MODE" = "remaining" ]; then
    echo "/home Mode     : Remaining space on $INSTALL_DRIVE"
else
    echo "/home Mode     : On separate drive $HOME_DRIVE"
fi

# Next phase would continue here (e.g., partitioning logic)...

