#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Audit (anomaly mode)
systemctl enable auditd.service

# USBGuard + companions for USB automount once authorized
systemctl enable usbguard.service
systemctl enable usbguard-dbus.service
systemctl enable udisks2.service

# Firewall + time
systemctl enable firewalld.service
systemctl enable chronyd.service

# Login manager: greetd replaces gdm
systemctl enable greetd.service
systemctl set-default graphical.target
systemctl disable gdm.service || true
systemctl mask gdm.service

# Hardware
systemctl enable framework-charge-limit.service
systemctl enable lock-before-sleep.service
systemctl enable pcscd.service

# Bluetooth disabled at boot; waybar toggle re-enables
systemctl disable bluetooth.service || true

echo "::endgroup::"
