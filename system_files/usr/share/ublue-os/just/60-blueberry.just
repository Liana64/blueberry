# Update the system: rpm-ostree, flatpaks, distrobox, and homebrew (if present)
update:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "update"
    gum spin --title "rpm-ostree update" -- rpm-ostree update
    gum spin --title "flatpak update"    -- flatpak update --user --noninteractive
    if command -v distrobox >/dev/null; then
        gum spin --title "distrobox upgrade" -- distrobox upgrade --all || bb_warn "distrobox: nothing to upgrade"
    fi
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        gum spin --title "brew upgrade" -- /home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi
    bb_ok "all up to date"

# Verify the running image's signature against the embedded cosign key
verify-image:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "verify-image"
    img="$(rpm-ostree status --json | jq -r '.deployments[0]."container-image-reference"' | sed 's|^[^:]*://||')"
    bb_step "image: $img"
    if cosign verify --key /etc/pki/containers/blueberry-cosign.pub "$img" >/dev/null 2>&1; then
        bb_ok "signature valid"
    else
        bb_err "signature verification FAILED"
        exit 1
    fi

# Roll back to the previous deployment (asks for confirmation first)
rollback:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "rollback"
    if ! gum confirm "Roll back to the previous deployment?"; then
        bb_warn "cancelled"
        exit 0
    fi
    rpm-ostree rollback
    bb_ok "rollback staged — reboot to apply"

# Assemble the default Fedora distrobox
assemble-distrobox:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "assemble-distrobox"
    distrobox assemble create --file /usr/share/blueberry/distrobox/distrobox.ini
    bb_ok "distrobox ready"

# Layer xdg-desktop-portal-wlr for screencasting (Vesktop/Zoom screen share)
[group('Toggles')]
enable-screencast:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "enable-screencast"
    if rpm -q xdg-desktop-portal-wlr >/dev/null 2>&1; then
        bb_ok "already installed"
        exit 0
    fi
    sudo rpm-ostree install xdg-desktop-portal-wlr
    bb_ok "layered — reboot to activate"
    if gum confirm "reboot now?"; then
        systemctl reboot
    fi

# Unlayer xdg-desktop-portal-wlr (no-op if not currently layered)
[group('Toggles')]
disable-screencast:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "disable-screencast"
    if ! rpm -q xdg-desktop-portal-wlr >/dev/null 2>&1; then
        bb_ok "not currently installed"
        exit 0
    fi
    sudo rpm-ostree uninstall xdg-desktop-portal-wlr
    bb_ok "unlayered — reboot to deactivate"
    if gum confirm "reboot now?"; then
        systemctl reboot
    fi

# Re-run the per-user Homebrew bundle (after Brewfile changes)
brew-bundle:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "brew-bundle"
    if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        bb_err "brew not installed"
        exit 1
    fi
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    gum spin --title "brew bundle" -- \
        brew bundle --file=/usr/share/blueberry/Brewfile
    bb_ok "brew bundle complete"

# Prune unused flatpaks, podman images, and rpm-ostree caches
clean:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "clean"
    gum spin --title "flatpak: prune unused" -- \
        flatpak uninstall --user --unused -y || bb_warn "flatpak: nothing to prune"
    if command -v podman >/dev/null; then
        gum spin --title "podman: prune images" -- \
            podman image prune -af || bb_warn "podman: nothing to prune"
    fi
    gum spin --title "rpm-ostree: cleanup" -- \
        sudo rpm-ostree cleanup -bm
    bb_ok "cleaned"

# Show recent security anomalies (SELinux denials, faillock, usbguard)
[group('Diagnostics')]
audit-summary:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "audit-summary (last 24h)"
    journalctl --since "24 hours ago" --no-pager 2>/dev/null \
        | grep -iE 'avc:|faillock|usbguard|policy violation' \
        || bb_ok "no anomalies"

# Enroll a fingerprint with fprintd
enroll-fingerprint:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "enroll-fingerprint"
    finger=$(printf '%s\n' \
        right-index-finger right-thumb right-middle-finger \
        left-index-finger  left-thumb  left-middle-finger \
        | gum choose --header "Which finger?")
    fprintd-enroll -f "$finger" "$USER"
    bb_ok "fingerprint enrolled ($finger)"

# Enroll a FIDO2 device (e.g. YubiKey) to unlock the LUKS root partition
enroll-fido2:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "enroll-fido2"
    mapfile -t devs < <(lsblk -lpno NAME,FSTYPE | awk '$2 == "crypto_LUKS" { print $1 }')
    if [ "${#devs[@]}" -eq 0 ]; then
        bb_err "no LUKS devices found"
        exit 1
    fi
    if [ "${#devs[@]}" -eq 1 ]; then
        target="${devs[0]}"
    else
        target=$(printf '%s\n' "${devs[@]}" | gum choose --header "Which LUKS device?")
    fi
    bb_step "enrolling FIDO2 token on $target"
    bb_warn "touch your token when it blinks"
    sudo systemd-cryptenroll --fido2-device=auto "$target"
    bb_ok "FIDO2 token enrolled"

# Generate and enroll Secure Boot keys, then sign the running deployment.
# Layers sbctl on first run; reboot once after enrollment so firmware picks up the new keys.
enroll-secure-boot:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "enroll-secure-boot"
    if ! command -v sbctl >/dev/null; then
        bb_warn "sbctl not installed — layering it now"
        sudo rpm-ostree install sbctl
        bb_warn "reboot, then re-run: ujust enroll-secure-boot"
        exit 0
    fi
    if ! gum confirm "Generate keys, enroll them in firmware, and sign the running deployment?"; then
        bb_warn "cancelled"
        exit 0
    fi
    sudo sbctl create-keys
    sudo sbctl enroll-keys --microsoft
    sudo sbctl sign-all
    bb_ok "secure boot configured — reboot, then verify with: sudo sbctl verify"

# Reset all rpm-ostree layered packages and overrides (returns to pristine image)
[group('Lifecycle')]
factory-reset:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "factory-reset"
    bb_warn "this drops all layered packages and overrides — system files in /etc are kept"
    if ! gum confirm "Continue with factory reset?"; then
        bb_warn "cancelled"
        exit 0
    fi
    sudo rpm-ostree reset
    bb_ok "reset staged — reboot to apply"

# Show timestamps of the current and previous deployments (a poor-man's changelog)
[group('Lifecycle')]
changelog:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "changelog"
    cur="$(rpm-ostree status --json | jq -r '.deployments[0].timestamp // empty')"
    prev="$(rpm-ostree status --json | jq -r '.deployments[1].timestamp // empty')"
    if [ -n "$cur" ]; then
        bb_step "current : $(date -d "@${cur}" 2>/dev/null || echo "$cur")"
    fi
    if [ -n "$prev" ]; then
        bb_step "previous: $(date -d "@${prev}" 2>/dev/null || echo "$prev")"
    else
        bb_warn "no previous deployment recorded"
    fi
    bb_warn "stub — full implementation tracked in TODO"

# Re-render the Blueberry message-of-the-day
[group('Lifecycle')]
motd:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "motd"
    if [ -r /etc/profile.d/blueberry-motd.sh ]; then
        # shellcheck disable=SC1091
        . /etc/profile.d/blueberry-motd.sh
    else
        bb_warn "stub — full implementation tracked in TODO"
    fi
    bb_ok "done"

# Repair user flatpak installation (permissions, caches, partial pulls)
[group('Lifecycle')]
fix-flatpak-permissions:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "fix-flatpak-permissions"
    gum spin --title "flatpak repair --user" -- flatpak repair --user || bb_warn "flatpak repair reported issues"
    bb_ok "flatpak user installation repaired"

# Install a WireGuard wg0 config that auto-connects on full network
# connectivity. The 90-wg-autoconnect NetworkManager dispatcher script
# (system_files/etc/NetworkManager/dispatcher.d/) brings wg0 up/down
# based on `CONNECTIVITY_STATE`, so once the config is in place the
# tunnel is fully managed for you.
[group('Setup')]
setup-vpn:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "setup-vpn"
    if [ -f /etc/wireguard/wg0.conf ]; then
        if ! gum confirm "/etc/wireguard/wg0.conf already exists. Overwrite?"; then
            bb_warn "cancelled"
            exit 0
        fi
    fi
    src="$(gum input --placeholder "Path to your wg0 .conf file")"
    if [ -z "$src" ]; then
        bb_err "no path provided"
        exit 1
    fi
    # Expand ~ and resolve symlinks so the error message points at the
    # real file the user typed.
    src="${src/#\~/$HOME}"
    if [ ! -r "$src" ]; then
        bb_err "cannot read: $src"
        exit 1
    fi
    sudo install -m 0600 -o root -g root -D "$src" /etc/wireguard/wg0.conf
    bb_ok "wg0.conf installed (root:root 0600)"
    bb_step "the NetworkManager dispatcher will auto-up wg0 once connectivity reaches FULL"
    if gum confirm "Bring wg0 up now?"; then
        if sudo wg-quick up wg0; then
            bb_ok "wg0 is up"
        else
            bb_err "wg-quick up wg0 failed — check the config and try again"
            exit 1
        fi
    fi

# Enable the user Syncthing service and open firewall ports 22000/tcp + 21027/udp
[group('Setup')]
setup-syncthing:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "setup-syncthing"
    bb_step "enabling user syncthing.service"
    systemctl --user enable --now syncthing.service || bb_warn "could not enable user unit"
    bb_step "opening firewall ports 22000/tcp and 21027/udp"
    sudo firewall-cmd --add-port=22000/tcp --permanent || bb_warn "firewall: 22000/tcp"
    sudo firewall-cmd --add-port=21027/udp --permanent || bb_warn "firewall: 21027/udp"
    sudo firewall-cmd --reload || bb_warn "firewall reload failed"
    bb_ok "syncthing setup complete"

# Generate a USBGuard policy from currently-attached devices and install it
[group('Setup')]
setup-usbguard:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "setup-usbguard"
    if ! command -v usbguard >/dev/null; then
        bb_err "usbguard not installed"
        exit 1
    fi
    bb_warn "this captures every USB device currently attached as 'allowed'"
    if ! gum confirm "Generate policy from current devices?"; then
        bb_warn "cancelled"
        exit 0
    fi
    sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
    sudo chmod 0600 /etc/usbguard/rules.conf
    sudo systemctl restart usbguard.service || bb_warn "usbguard restart failed"
    bb_ok "usbguard policy installed at /etc/usbguard/rules.conf"

# Set the current user's login shell to zsh. Uses sudo + usermod rather
# than chsh because Fedora's /etc/pam.d/chsh requires a password prompt
# that doesn't work from non-interactive contexts (e.g. firstboot).
[group('Setup')]
set-default-shell-zsh:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "set-default-shell-zsh"
    if ! [ -x /usr/bin/zsh ]; then
        bb_err "zsh not installed"
        exit 1
    fi
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$current" = "/usr/bin/zsh" ]; then
        bb_ok "already using zsh"
        exit 0
    fi
    bb_step "current shell: $current"
    sudo usermod -s /usr/bin/zsh "$USER"
    bb_ok "login shell set to zsh — log out and back in to take effect"

# Enroll a YubiKey for U2F login (writes ~/.config/Yubico/u2f_keys)
[group('Setup')]
enroll-yubikey:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "enroll-yubikey"
    bb_warn "stub — full implementation tracked in TODO"
    bb_step "expected flow: pamu2fcfg >> ~/.config/Yubico/u2f_keys"
    exit 0

# Flip bluetooth.service between enabled+running and disabled+stopped
[group('Toggles')]
toggle-bluetooth:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "toggle-bluetooth"
    if systemctl is-enabled --quiet bluetooth.service; then
        sudo systemctl disable --now bluetooth.service
        bb_ok "bluetooth disabled"
    else
        sudo systemctl enable --now bluetooth.service
        bb_ok "bluetooth enabled"
    fi

# Toggle a writable /usr overlay for ad-hoc development (lost on reboot)
[group('Toggles')]
toggle-devmode:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "toggle-devmode"
    bb_warn "stub — full implementation tracked in TODO"
    bb_step "intended semantics: sudo rpm-ostree usroverlay (transient until reboot)"
    exit 0

# Install Cider (Apple Music client) inside a dedicated distrobox + export desktop entry
[group('Toggles')]
install-cider:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "install-cider"
    bb_warn "stub — full implementation tracked in TODO"
    bb_step "intended: distrobox create apps-cider && distrobox-export --app cider"
    exit 0

# Pick from a curated extras menu (real list deferred)
[group('Toggles')]
install-extras:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "install-extras"
    bb_warn "stub — full implementation tracked in TODO"
    bb_step "intended: gum choose over a curated package list"
    exit 0
