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

# Toggle the Framework charge limit between 80% and 100%
toggle-charge-limit:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "toggle-charge-limit"
    f=/sys/class/power_supply/BAT1/charge_control_end_threshold
    cur="$(cat "$f")"
    if [ "$cur" = "80" ]; then
        new=100
    else
        new=80
    fi
    echo "$new" | sudo tee "$f" >/dev/null
    bb_ok "charge limit: ${cur}% → ${new}%"
