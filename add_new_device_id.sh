#!/bin/bash
#
# Applies patches to the 'vendor-reset' source for a given device ID
# and reports changes. This script is idempotent.
#
# Usage: ./add_new_device_id.sh [DEVICE_ID]
# Default DEVICE_ID is 1638 if not provided.

set -e

# --- Configuration ---

# Use the first command-line argument as the device ID, or default to "1638".
DEVICE_ID="${1:-1638}"
MODULE_NAME="vendor-reset"
MODULE_VERSION="0.1.1"
DKMS_MODULE_STRING="${MODULE_NAME}/${MODULE_VERSION}"

# The project root is the directory where this script is located.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define file paths
ATOM_C_FILE="$ROOT_DIR/src/amd/amdgpu/atom.c"
DEVICE_DB_FILE="$ROOT_DIR/src/device-db.h"
UDEV_RULES_FILE="$ROOT_DIR/udev/99-vendor-reset.rules"

# --- Script Logic ---

echo "--- Checking vendor-reset patches for Device ID: 0x$DEVICE_ID ---"

# 1. Patch atom.c: Replace include (This patch is device-independent)
echo -n "Checking patch for src/amd/amdgpu/atom.c... "
if grep -qF '#include <linux/unaligned.h>' "$ATOM_C_FILE"; then
  echo "No change needed (already patched)."
else
  sed -i 's|#include <asm/unaligned.h>|#include <linux/unaligned.h>|' "$ATOM_C_FILE"
  echo "Patch applied."
fi

# 2. Patch device-db.h: Add the new device ID
echo -n "Checking patch for src/device-db.h... "
if grep -qF "0x${DEVICE_ID}" "$DEVICE_DB_FILE"; then
  echo "No change needed (Device ID 0x${DEVICE_ID} already exists)."
else
  # Define the new line with the specified device ID
  new_device_line="    {PCI_VENDOR_ID_ATI, 0x${DEVICE_ID}, op, DEVICE_INFO(AMD_NAVI10)}, \\\\"
  # Insert the new line before the anchor line
  sed -i "/{PCI_VENDOR_ID_ATI, 0x7310, op, DEVICE_INFO(AMD_NAVI10)}, \\\\/i ${new_device_line}" "$DEVICE_DB_FILE"
  echo "Patch applied (added Device ID 0x${DEVICE_ID})."
fi

# 3. Patch udev rules: Add a rule for the new device
echo -n "Checking patch for udev/99-vendor-reset.rules... "
if grep -qF "ATTR{device}==\"0x${DEVICE_ID}\"" "$UDEV_RULES_FILE"; then
  echo "No change needed (Rule for 0x${DEVICE_ID} already exists)."
else
  # Define the new rule with the specified device ID. Note the escaped '$' in sys\$env
  new_udev_rule="ACTION==\"add\", SUBSYSTEM==\"pci\", ATTR{vendor}==\"0x1002\", ATTR{device}==\"0x${DEVICE_ID}\", RUN+=\"/bin/sh -c '/sbin/modprobe vendor-reset; echo device_specific > /sys\\\$env{DEVPATH}/reset_method'\""
  # Insert the new rule after line 2
  sed -i "2a ${new_udev_rule}" "$UDEV_RULES_FILE"
  echo "Patch applied (added rule for Device ID 0x${DEVICE_ID})."
fi

echo "--- Patch check complete. ---"
echo ""

# --- DKMS Rebuild Logic ---
echo "--- Performing a clean rebuild of DKMS module: ${DKMS_MODULE_STRING} ---"

# Check if the dkms command is available
if ! command -v sudo dkms &>/dev/null; then
    echo "'dkms' command not found. Will install the DKMS package now." >&2
    sudo apt install dkms
fi

echo "Step 1: Uninstalling any active module..."
sudo dkms uninstall "$DKMS_MODULE_STRING" || true

echo "Step 2: Removing the module from the DKMS tree..."
sudo dkms remove "$DKMS_MODULE_STRING" --all || true

echo "Step 3: Forcing installation of the new module..."
# The '--force' flag is critical here to bypass the sanity check and overwrite the module.
sudo dkms install --force "$DKMS_MODULE_STRING"

echo "--- DKMS rebuild complete. ---"