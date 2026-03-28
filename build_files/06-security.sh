#!/bin/bash
# Security packages: USBGuard, YubiKey U2F, WireGuard

dnf5 install -y \
    usbguard \
    pam-u2f \
    pamu2fcfg \
    wireguard-tools \
    yubikey-manager \
    yubikey-personalization \
    pcsc-lite \
    gnupg2
