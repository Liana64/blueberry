#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

systemctl enable auditd.service

# usbguard.service handles its own D-Bus integration; Fedora ships no
# separate usbguard-dbus.service.
systemctl enable usbguard.service
systemctl enable udisks2.service

systemctl enable firewalld.service
systemctl enable chronyd.service

systemctl enable fstrim.timer
systemctl enable smartd.service

# power-profiles-daemon (not TLP)
systemctl enable power-profiles-daemon.service

# greetd replaces gdm
systemctl enable greetd.service
systemctl set-default graphical.target
systemctl disable gdm.service || true
systemctl mask gdm.service

systemctl enable framework-charge-limit.service
# lock-before-sleep is handled user-side by swayidle's `before-sleep` handler
# (see etc/sway/config). A system-level swaylock invocation can't reach the
# user's wayland socket, so this used to fail silently — it has been removed.
systemctl enable pcscd.service

# Bluetooth disabled at boot; waybar toggle re-enables
systemctl disable bluetooth.service || true

# Spec §2 — services that must never run on Blueberry by default.
# Some of these are not installed on base-main; `|| true` keeps the build
# idempotent across base image churn.
# xdg-desktop-portal-wlr is intentionally NOT shipped in the image — it is
# layered on demand by `ujust enable-screencast`. No mask needed: when the
# package isn't installed, the unit simply doesn't exist.
for svc in avahi-daemon.service cups-browsed.service geoclue.service \
           packagekit.service abrt-journal-core.service abrt-oops.service \
           abrt-vmcore.service abrt-xorg.service abrtd.service; do
    systemctl mask "$svc" || true
done

echo "::endgroup::"
