#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Bulk Fedora repos here; COPR packages go via copr_install_isolated
# (see copr-helpers.sh) to prevent COPR injection.

FEDORA_PACKAGES=(
    # theming / fonts / cursors (GTK + sway desktop)
    adw-gtk3-theme
    adwaita-fonts-all
    papirus-icon-theme

    # security / hardening
    audit
    usbguard
    pam
    firewalld
    chrony
    setools-console

    # login + session
    greetd
    greetd-tuigreet
    polkit
    polkit-qt

    # sway desktop
    sway
    swaylock
    swayidle
    swaybg
    waybar
    mako
    rofi
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
    gnome-keyring
    libnotify
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    syncthing
    nmap
    nmap-ncat

    # audio
    pipewire
    pipewire-pulseaudio
    pipewire-jack-audio-connection-kit
    wireplumber
    easyeffects

    # networking
    NetworkManager-wifi
    wireguard-tools

    # bluetooth
    bluez
    blueman

    # firmware / hardware management
    fwupd
    fprintd
    bolt
    ddcutil
    power-profiles-daemon
    upower

    # smartcards / yubikey
    pcsc-lite
    pcsc-lite-ccid
    yubikey-manager
    pam-u2f

    # containers + dev tooling layered on host
    flatpak
    distrobox
    podman
    just
    git
    vim
    zsh
    util-linux-user
    tmux
    direnv

    # terminal (used by sway's startup session and the first-boot welcome
    # window, before any user dotfiles have been deployed)
    kitty

    # shell ergonomics (referenced by aliases / zsh init)
    bat
    btop
    duf
    du-dust
    eza
    fastfetch
    fd-find
    fortune-mod
    fzf
    git-delta
    procs
    ripgrep
    zoxide

    # general system / build tools
    age
    gdisk
    gum
    ImageMagick
    ffmpeg-free
    jq
    moreutils
    pciutils
    pre-commit
    shellcheck
    traceroute
    unzip
    usbutils
    wget
    yq

    # diagnostics / sysadmin
    bind-utils
    bc
    perf
    inotify-tools
    lm_sensors
    smartmontools
    dmidecode
    ethtool
    hdparm
    nvme-cli
    sysstat
    tcpdump
    wireshark-cli

    # storage / automount / backup
    udisks2
    gvfs
    restic
    rclone
    borgbackup
    cryfs

    # fonts
    google-noto-fonts-common
    google-noto-emoji-fonts
    jetbrains-mono-fonts-all
    # Nerd Font for waybar/sway icon glyphs (Fedora has no jetbrains-mono
    # nerd variant in F43 repos; cascadia-mono-nf is the closest mono nerd
    # font Fedora actually ships).
    cascadia-mono-nf-fonts

    # boot splash
    plymouth
    plymouth-plugin-script
)

# Version-specific additions go here as the F44 fork lands.
case "$(rpm -E %fedora)" in
    43) ;;
    44) ;;
esac

echo "Installing ${#FEDORA_PACKAGES[@]} packages from Fedora repos..."
dnf -y install "${FEDORA_PACKAGES[@]}"

# Packages base-main pulls in but we don't want.
EXCLUDED_PACKAGES=(
    firefox
    firefox-langpacks
    gnome-software
    gnome-software-rpm-ostree
)

if [[ ${#EXCLUDED_PACKAGES[@]} -gt 0 ]]; then
    readarray -t INSTALLED_EXCLUDED < <(rpm -qa --queryformat='%{NAME}\n' "${EXCLUDED_PACKAGES[@]}" 2>/dev/null || true)
    if [[ ${#INSTALLED_EXCLUDED[@]} -gt 0 ]]; then
        dnf -y remove "${INSTALLED_EXCLUDED[@]}"
    else
        echo "No excluded packages found to remove."
    fi
fi

echo "::endgroup::"
