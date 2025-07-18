#!/bin/bash
set -e

# === IMPORT CONFIG FROM ENV ===
: "${BOOT_MODE:?}" "${INSTALL_DRIVE:?}" "${SWAP_SIZE:?}" "${HOME_MODE:?}" "${ROOT_FS:?}" "${HOME_FS:?}"

# Optional depending on HOME_MODE
: "${HOME_SIZE:=}"
: "${HOME_DRIVE:=}"

# Output partition names
BOOT_PART=""
SWAP_PART=""
ROOT_PART=""
HOME_PART=""

partition_disks() {
    echo "Wiping and partitioning $INSTALL_DRIVE..."
    wipefs -a "$INSTALL_DRIVE"
    parted -s "$INSTALL_DRIVE" mklabel gpt

    if [ "$BOOT_MODE" = "UEFI" ]; then
        parted -s "$INSTALL_DRIVE" mkpart ESP fat32 1MiB 513MiB
        parted -s "$INSTALL_DRIVE" set 1 esp on
    else
        parted -s "$INSTALL_DRIVE" mklabel msdos
        parted -s "$INSTALL_DRIVE" mkpart primary ext4 1MiB 513MiB
        parted -s "$INSTALL_DRIVE" set 1 boot on
    fi
    BOOT_PART="${INSTALL_DRIVE}1"
    NEXT_START=513MiB

    parted -s "$INSTALL_DRIVE" mkpart primary linux-swap "$NEXT_START" "$SWAP_SIZE"
    SWAP_PART="${INSTALL_DRIVE}2"

    if [ "$HOME_MODE" = "fixed" ]; then
        DRIVE_SIZE=$(lsblk -b -n -d -o SIZE "$INSTALL_DRIVE")
        HOME_BYTES=$(numfmt --from=iec "$HOME_SIZE")
        ROOT_END_BYTES=$(( DRIVE_SIZE - HOME_BYTES ))
        ROOT_END=$(numfmt --to=iec --suffix=B "$ROOT_END_BYTES")
        parted -s "$INSTALL_DRIVE" mkpart primary "$ROOT_FS" "$SWAP_SIZE" "$ROOT_END"
        parted -s "$INSTALL_DRIVE" mkpart primary "$HOME_FS" "$ROOT_END" 100%
        ROOT_PART="${INSTALL_DRIVE}3"
        HOME_PART="${INSTALL_DRIVE}4"
    elif [ "$HOME_MODE" = "remaining" ]; then
        parted -s "$INSTALL_DRIVE" mkpart primary "$ROOT_FS" "$SWAP_SIZE" 100%
        ROOT_PART="${INSTALL_DRIVE}3"
    elif [ "$HOME_MODE" = "other" ]; then
        parted -s "$INSTALL_DRIVE" mkpart primary "$ROOT_FS" "$SWAP_SIZE" 100%
        ROOT_PART="${INSTALL_DRIVE}3"
        wipefs -a "$HOME_DRIVE"
        parted -s "$HOME_DRIVE" mklabel gpt
        parted -s "$HOME_DRIVE" mkpart primary "$HOME_FS" 1MiB 100%
        HOME_PART="${HOME_DRIVE}1"
    fi
}

format_partitions() {
    echo "Formatting partitions..."
    [[ "$BOOT_MODE" = "UEFI" ]] && mkfs.fat -F32 "$BOOT_PART" || mkfs.ext4 "$BOOT_PART"
    mkswap "$SWAP_PART" && swapon "$SWAP_PART"
    mkfs."$ROOT_FS" "$ROOT_PART"
    [[ "$HOME_MODE" != "remaining" ]] && mkfs."$HOME_FS" "$HOME_PART"
}

mount_partitions() {
    echo "Mounting partitions..."
    mount "$ROOT_PART" /mnt

    mkdir -p /mnt/boot
    if [ "$BOOT_MODE" = "UEFI" ]; then
        mkdir -p /mnt/boot/efi
        mount "$BOOT_PART" /mnt/boot/efi
    else
        mount "$BOOT_PART" /mnt/boot
    fi

    if [ "$HOME_MODE" != "remaining" ]; then
        mkdir -p /mnt/home
        mount "$HOME_PART" /mnt/home
    fi
}

# === MAIN EXECUTION ===
partition_disks
format_partitions
mount_partitions

echo "=== Disk setup complete. Ready for base system install. ==="
