#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Enabling/disabling system units"

# Audit (anomaly mode)
enable_unit auditd.service

# USBGuard + companions for USB automount once authorized
enable_unit usbguard.service
enable_unit usbguard-dbus.service
enable_unit udisks2.service

# Firewall + time
enable_unit firewalld.service
enable_unit chronyd.service

# Login manager: greetd replaces gdm
enable_unit greetd.service
systemctl set-default graphical.target
disable_unit gdm.service
mask_unit gdm.service
