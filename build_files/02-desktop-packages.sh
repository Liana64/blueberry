#!/bin/bash
# Desktop environment packages (Sway + Wayland stack)

dnf5 install -y \
    sway \
    swayidle \
    swaylock \
    waybar \
    rofi-wayland \
    mako \
    wl-clipboard \
    wlr-randr \
    gdm \
    xdg-desktop-portal-wlr \
    xdg-desktop-portal-gtk \
    grim \
    slurp \
    brightnessctl \
    playerctl \
    kanshi \
    light \
    autotiling-rs \
    swaybg \
    kitty \
    thunar \
    pavucontrol \
    seahorse \
    polkit-gnome
