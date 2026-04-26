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

# Set the Framework charge end-threshold (60-100). Persists across resume via systemd unit.
[group('Hardware')]
framework-charge-limit:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "framework-charge-limit"
    f=/sys/class/power_supply/BAT1/charge_control_end_threshold
    if [ ! -w "$f" ] && [ ! -e "$f" ]; then
        bb_err "charge_control_end_threshold not present — is this a Framework?"
        exit 1
    fi
    cur="$(cat "$f" 2>/dev/null || echo "?")"
    bb_step "current limit: ${cur}%"
    new="$(gum input --placeholder "60-100" --prompt "new charge limit %: ")"
    if ! [[ "$new" =~ ^[0-9]+$ ]] || [ "$new" -lt 60 ] || [ "$new" -gt 100 ]; then
        bb_err "value must be an integer in 60-100"
        exit 1
    fi
    echo "$new" | sudo tee "$f" >/dev/null
    bb_ok "charge limit: ${cur}% → ${new}%"

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
# Layers sbctl on first run; reboot once after enrollment so firmware

# picks up the new keys.
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
