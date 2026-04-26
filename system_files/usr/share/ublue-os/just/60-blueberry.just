# Update the system: rpm-ostree, flatpaks, distrobox, and homebrew (if present)
update:
    rpm-ostree update
    flatpak update --user --noninteractive
    -distrobox upgrade --all
    -[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && /home/linuxbrew/.linuxbrew/bin/brew upgrade

# Verify the running image's signature against the embedded cosign key
verify-image:
    #!/usr/bin/env bash
    set -eu
    img="$(rpm-ostree status --json | jq -r '.deployments[0]."container-image-reference"' | sed 's|^[^:]*://||')"
    cosign verify --key /etc/pki/containers/blueberry-cosign.pub "$img"

# Roll back to the previous deployment
rollback:
    rpm-ostree rollback
    @echo "Reboot to apply."

# Assemble the default Fedora distrobox
assemble-distrobox:
    distrobox assemble create --file /usr/share/blueberry/distrobox/distrobox.ini

# Toggle the Framework charge limit between 80% and 100%
toggle-charge-limit:
    #!/usr/bin/env bash
    set -eu
    f=/sys/class/power_supply/BAT1/charge_control_end_threshold
    cur="$(cat "$f")"
    if [ "$cur" = "80" ]; then
        echo 100 | sudo tee "$f"
    else
        echo 80 | sudo tee "$f"
    fi
