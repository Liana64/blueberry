#!/bin/bash
# Framework 13 AMD hardware support

dnf5 install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    libva-utils \
    libva-mesa-driver \
    power-profiles-daemon

# AMD GPU kernel args
# Note: For bootc, kernel args are typically set via /etc/kernel/cmdline
# or via bootc kargs. This file is read by the bootloader.
mkdir -p /etc/kernel
if [ -f /etc/kernel/cmdline ]; then
    # Append to existing cmdline
    sed -i 's/$/ amdgpu.sg_display=0 amdgpu.dcdebugmask=0x10 amdgpu.abm_level=0/' /etc/kernel/cmdline
else
    echo "amdgpu.sg_display=0 amdgpu.dcdebugmask=0x10 amdgpu.abm_level=0" > /etc/kernel/cmdline
fi
