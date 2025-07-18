#!/bin/bash
set -e

# === Config ===
DISK="/dev/nvme0n1"  # Change if needed
HOSTNAME="arch-xps"
USERNAME="user"
PASSWORD="password"  # Change later
LOCALE="en_US.UTF-8"
TIMEZONE="America/New_York"
DE_LIST=("gnome" "kde" "xfce" "cinnamon" "lxqt")

# === Prompt DE selection ===
echo "Select a desktop environment:"
select DE in "${DE_LIST[@]}"; do
    [[ -n "$DE" ]] && break
done
echo "You selected: $DE"

# === Partition Disk ===
sgdisk -Z $DISK
sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI" $DISK
sgdisk -n2:0:0 -t2:8300 -c2:"ROOT" $DISK
EFI="${DISK}p1"
ROOT="${DISK}p2"

# === Format Partitions ===
mkfs.fat -F32 $EFI
mkfs.btrfs -f $ROOT

# === Mount Btrfs ===
mount $ROOT /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
umount /mnt

mount -o noatime,compress=zstd,space_cache=v2,subvol=@ $ROOT /mnt
mkdir -p /mnt/{boot,home,.snapshots}
mount -o subvol=@home $ROOT /mnt/home
mount -o subvol=@snapshots $ROOT /mnt/.snapshots
mount $EFI /mnt/boot

# === Install Base System ===
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs grub efibootmgr networkmanager iwd intel-ucode

# === Generate fstab ===
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot Setup ===
arch-chroot /mnt /bin/bash <<EOF

# Time & Locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# User & Password
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install DE + X
pacman --noconfirm -S xorg

case "$DE" in
  gnome) pacman --noconfirm -S gnome gdm ;;
  kde) pacman --noconfirm -S plasma kde-applications sddm ;;
  xfce) pacman --noconfirm -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter ;;
  cinnamon) pacman --noconfirm -S cinnamon lightdm lightdm-gtk-greeter ;;
  lxqt) pacman --noconfirm -S lxqt sddm ;;
esac

# Enable services
systemctl enable NetworkManager

case "$DE" in
  gnome) systemctl enable gdm ;;
  kde|lxqt) systemctl enable sddm ;;
  xfce|cinnamon) systemctl enable lightdm ;;
esac

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# === Done ===
echo "Installation complete! You can reboot now."
