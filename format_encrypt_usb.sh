#!/bin/bash

# Detect first external, physical USB disk (there is for sure a better way to do this, but for me this works right now)
USB_DISK=$(diskutil list | grep -B1 "external, physical" | grep "/dev/disk" | awk '{print $1}' | head -n1)
echo "$USB_DISK is selected as your fighter"

# Abort if no USB found
if [ -z "$USB_DISK" ]; then
    echo "❌ No external USB disk found. Aborting."
    exit 1
fi

# Get current volume name (may be empty if unformatted)
CURRENT_VOLUME=$(diskutil info "$USB_DISK" | awk -F': *' '/Volume Name/ {print $2}')


echo "⚠️  About to ERASE and ENCRYPT the USB stick:"
echo "    Disk:        $USB_DISK"
echo "    Volume Name: ${CURRENT_VOLUME:-<No Name>}"
read -p "❓ Do you want to continue? Type YES to proceed: " confirm

if [[ "$confirm" != "YES" ]]; then
    echo "Aborted by user."
    exit 1
fi

# Prompt for new volume name
read -p "📝 Enter a name for the USB stick (volume label): " VOLUME_NAME
echo

# Prompt for password
read -s -p "🔐 Enter encryption password: " PASSWORD
echo
read -s -p "🔐 Confirm password: " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
    echo "❌ Passwords do not match. Aborting."
    exit 1
fi

# Make sure terminal isn't in /Volumes/<disk>, otherwise unmount will fail
cd ~

# force delete
echo "📛 Forcibly unmounting $USB_DISK..."
diskutil unmountDisk force "$USB_DISK" || {
    echo "❌ Could not unmount $USB_DISK. It may be in use by another process."
    lsof | grep "$USB_DISK"
    exit 1
}

# Reformat to plain APFS with known name
diskutil eraseDisk APFS "TempLabel" "$USB_DISK" # this is for mac os, not sure what you need for other os

# check if it worked
if ! diskutil info /Volumes/TempLabel &>/dev/null; then
    echo "❌ Formatting failed — /Volumes/TempLabel not found."
    exit 1
fi

# Wait a moment for the system to register the new volume
echo "lemme sleep for a minute"
sleep 2


# Extract APFS volume from known TempLabel mount
APFS_VOLUME=$(diskutil info /Volumes/TempLabel | awk -F': *' '/Device Node/ {print $2}' | xargs)

if [[ -z "$APFS_VOLUME" || "$APFS_VOLUME" == "/dev/" ]]; then
    echo "❌ Failed to detect APFS volume after formatting."
    exit 1
fi

# Encrypt the volume (since we use APFS we can encrypt after the creation; is that bad?)
echo "🧨 Encrypting $APFS_VOLUME with password..."
diskutil apfs encryptVolume "$APFS_VOLUME" -user disk -passphrase "$PASSWORD"

if [ $? -eq 0 ]; then
    echo "✅ Encrypted volume created. Renaming to: $VOLUME_NAME"
    diskutil rename "$APFS_VOLUME" "$VOLUME_NAME"
else
    echo "❌ Encryption failed."
    exit 1
fi