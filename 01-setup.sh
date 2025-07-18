#!/bin/bash
set -e

# === ENV VARS ===
BOOT_MODE=""
INSTALL_DRIVE=""
SWAP_SIZE=""
HOME_MODE=""
HOME_SIZE=""
HOME_DRIVE=""
ROOT_FS=""
HOME_FS=""

# === FUNCTIONS ===

detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI mode detected."
        BOOT_MODE="UEFI"
    else
        echo "BIOS mode detected."
        BOOT_MODE="BIOS"
    fi
}

list_drives() {
    echo "Available drives:"
    lsblk -d -n -e 7,11 -o NAME,SIZE,MODEL | while read -r name size model; do
        echo "/dev/$name - $size ($model)"
    done
}

select_install_drive() {
    echo "Enter the drive to install Arch on (e.g., /dev/sda):"
    read -rp "> " INSTALL_DRIVE
    if [ ! -b "$INSTALL_DRIVE" ]; then
        echo "Invalid drive selected."
        exit 1
    fi
}

configure_home_partition() {
    echo "Configure /home partition:"
    echo "1) Use remaining space on main drive"
    echo "2) Specify fixed size on main drive"
    echo "3) Use another drive if available"
    read -rp "Select option [1-3]: " HOME_OPTION

    case "$HOME_OPTION" in
        1) HOME_MODE="remaining" ;;
        2)
            read -rp "Enter fixed size for /home (e.g., 20G): " HOME_SIZE
            HOME_MODE="fixed"
            ;;
        3)
            echo "Looking for other drives..."
            OTHER_DRIVES=$(lsblk -d -n -e 7,11 -o NAME | grep -v "$(basename "$INSTALL_DRIVE")")
            if [ -z "$OTHER_DRIVES" ]; then
                echo "No additional drives found. Defaulting to remaining space."
                HOME_MODE="remaining"
            else
                echo "Available secondary drives:"
                echo "$OTHER_DRIVES" | while read -r name; do
                    lsblk -d -n -o NAME,SIZE,MODEL "/dev/$name"
                done
                read -rp "Select drive for /home (e.g., /dev/sdb): " HOME_DRIVE
                if [ ! -b "$HOME_DRIVE" ]; then
                    echo "Invalid drive."
                    exit 1
                fi
                HOME_MODE="other"
            fi
            ;;
        *) echo "Invalid option."; exit 1 ;;
    esac
}

configure_swap() {
    read -rp "Enter swap partition size (e.g., 2G): " SWAP_SIZE
    if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[MG]$ ]]; then
        echo "Invalid swap size format. Use number + M or G."
        exit 1
    fi
}

select_filesystems() {
    echo "Choose filesystem for root (/):"
    select ROOT_FS in ext4 btrfs xfs; do [[ $ROOT_FS ]] && break; done

    echo "Choose filesystem for /home:"
    select HOME_FS in ext4 btrfs xfs; do [[ $HOME_FS ]] && break; done
}

# === MAIN EXECUTION ===
clear
echo "=== Arch Install: Setup Phase ==="

detect_boot_mode
echo
list_drives
select_install_drive
echo
configure_home_partition
configure_swap
echo
select_filesystems

# Export all config for use in next script
export BOOT_MODE INSTALL_DRIVE SWAP_SIZE HOME_MODE HOME_SIZE HOME_DRIVE ROOT_FS HOME_FS
