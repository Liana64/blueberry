#!/bin/bash
# Core system packages

dnf5 install -y \
    NetworkManager \
    firewalld \
    chrony \
    fwupd \
    fprintd \
    fprintd-pam \
    bolt \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber \
    polkit \
    rtkit \
    gnome-keyring \
    bluez \
    btrfs-progs \
    udisks2 \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    flatpak \
    smartmontools \
    nvme-cli \
    traceroute \
    wget \
    libsecret \
    ImageMagick \
    dconf
