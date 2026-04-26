#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Audit (anomaly mode)
systemctl enable auditd.service

# USBGuard + companions for USB automount once authorized
# (usbguard.service handles its own D-Bus integration; no separate
#  usbguard-dbus.service ships in the Fedora package.)
systemctl enable usbguard.service
systemctl enable udisks2.service

# Firewall + time
systemctl enable firewalld.service
systemctl enable chronyd.service

# Storage health
systemctl enable fstrim.timer
systemctl enable smartd.service

# Power management (NixOS uses power-profiles-daemon, not TLP)
systemctl enable power-profiles-daemon.service

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

# Spec §2 — services that must never run on Blueberry by default.
# Some of these are not installed on base-main; `|| true` keeps the build
# idempotent across base image churn.
for svc in avahi-daemon.service cups-browsed.service geoclue.service \
           packagekit.service abrt-journal-core.service abrt-oops.service \
           abrt-vmcore.service abrt-xorg.service abrtd.service \
           xdg-desktop-portal-wlr.service; do
    systemctl mask "$svc" || true
done

echo "::endgroup::"
