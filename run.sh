#!/bin/sh
#
# create_uefi_disk.sh — Build a GPT disk image with a proper EFI System Partition,
# copy BOOTX64.EFI into it, then boot it with QEMU using OVMF.
#
# This script automates:
#   1. Creating a raw .img disk if missing
#   2. Partitioning it using GPT + EFI System Partition (gdisk EF00)
#   3. Attaching image to macOS as a raw disk device
#   4. Formatting EFI partition as FAT32
#   5. Mounting the EFI partition
#   6. Installing BOOTX64.EFI into /EFI/BOOT/
#   7. Detaching + launching QEMU
#
# Requirements:
#   - macOS
#   - OVMF.bin (UEFI firmware)
#   - BOOTX64.EFI compiled by your Makefile
#

set -e  # Exit on error

IMG="UEFI_TEST_DISK.img"
ESP_SIZE_MB=100
MNT="/Volumes/ESP"

###############################################################################
# 0. Cleanup helper — unmount + detach if previous run left residual devices
###############################################################################
cleanup_old() {
    # If ESP mount exists → unmount it
    if mount | grep -q "$MNT"; then
        echo "[CLEAN] Unmounting old ESP..."
        sudo umount "$MNT" || true
    fi

    # Detach stale disk image devices
    ATTACHED=$(hdiutil info | grep "$IMG" | awk '{print $1}')
    if [ -n "$ATTACHED" ]; then
        echo "[CLEAN] Detaching old device: $ATTACHED"
        hdiutil detach "$ATTACHED" || true
    fi
}

cleanup_old

###############################################################################
# 1. Always create a NEW blank raw disk image
###############################################################################
echo "[+] Creating new raw disk: $IMG"
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1m count=64

###############################################################################
# 2. Build UEFI BOOTX64.EFI
###############################################################################
echo "[+] Building BOOTX64.EFI..."
make clean
make

###############################################################################
# 2. Partition using GPT (gdisk)
###############################################################################
echo "[+] Creating GPT and EFI System Partition..."
sudo gdisk "$IMG" <<EOF
o
y
n
1


+${ESP_SIZE_MB}M
EF00
w
y
EOF

###############################################################################
# 3. Attach the disk image so macOS assigns a /dev/diskX handle
###############################################################################
echo "[+] Attaching disk image..."
DEV=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "$IMG" \
    | head -n1 | awk '{print $1}')

echo "[+] Attached as: $DEV"

ESP_DEV="${DEV}s1"   # macOS convention for partition 1

###############################################################################
# 4. Format EFI System Partition as FAT32
###############################################################################
echo "[+] Formatting EFI System Partition (FAT32)..."
sudo newfs_msdos -F 32 "$ESP_DEV"

###############################################################################
# 5. Mount EFI partition and install BOOTX64.EFI
###############################################################################
MNT="/Volumes/ESP"
echo "[+] Mounting ESP to: $MNT"
sudo mkdir -p "$MNT"
sudo mount -t msdos "$ESP_DEV" "$MNT"

echo "[+] Installing BOOTX64.EFI..."
sudo mkdir -p "$MNT/EFI/BOOT"
sudo cp BOOTX64.EFI "$MNT/EFI/BOOT/"

###############################################################################
# 6. Unmount and detach disk image
###############################################################################
echo "[+] Cleaning up..."
sudo umount "$MNT"
hdiutil detach "$DEV"

echo "[+] EFI System Partition created successfully."

###############################################################################
# 7. Boot image using QEMU + OVMF
###############################################################################
echo "[+] Launching QEMU..."
qemu-system-x86_64 \
    -drive format=raw,unit=0,file="$IMG" \
    -net none \
    -machine q35 \
    -name TESTOS \
    -bios OVMF.bin \
    -vga virtio
