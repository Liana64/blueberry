#!/bin/bash
# Enable systemd services

systemctl enable gdm
systemctl enable NetworkManager
systemctl enable firewalld
systemctl enable fwupd
systemctl enable fprintd
systemctl enable bluetooth
systemctl enable chronyd
systemctl enable power-profiles-daemon
systemctl enable usbguard
systemctl enable pcscd.socket
