#!/bin/bash
# Font installation

# From Fedora repos
dnf5 install -y \
    google-noto-sans-fonts \
    google-noto-emoji-fonts \
    unzip

# JetBrains Mono Nerd Font (direct download)
FONT_VERSION="3.3.0"
FONT_DIR="/usr/share/fonts/jetbrains-mono-nerd"
mkdir -p "$FONT_DIR"
curl -fsSL -o /tmp/JetBrainsMono.zip \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VERSION}/JetBrainsMono.zip"
unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
rm -f /tmp/JetBrainsMono.zip
fc-cache -f
