#!/bin/bash
sudo rmmod vendor_reset 2>/dev/null || true
sudo dkms remove vendor-reset/0.1.1 --all 2>/dev/null || true
sudo dkms install /home/nasadmin/vendor-reset || { echo "❌ Build failed!"; exit 1; }
sudo modprobe vendor_reset || { echo "❌ Module load failed!"; exit 1; }

# Verify it worked
if lsmod | grep -q vendor_reset; then
    echo "✅ vendor_reset loaded successfully"
    dmesg | tail -5 | grep vendor_reset
else
    echo "❌ vendor_reset NOT loaded"
    exit 1
fi
