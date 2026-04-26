#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Packages are split into FEDORA_PACKAGES (bulk install from Fedora repos,
# safe from COPR injection) and any COPR packages (installed individually
# via copr_install_isolated). See build_files/copr-helpers.sh.

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
