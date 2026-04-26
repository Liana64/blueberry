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

# Refresh fwupd metadata and apply any pending firmware updates
[group('Hardware')]
framework-firmware-update:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "framework-firmware-update"
    if ! command -v fwupdmgr >/dev/null; then
        bb_err "fwupdmgr not installed"
        exit 1
    fi
    gum spin --title "fwupdmgr refresh" -- fwupdmgr refresh -y || bb_warn "refresh reported issues"
    fwupdmgr update -y || bb_warn "no updates applied"
    bb_ok "firmware update flow complete"

# Mark the EasyEffects DSP profile as enabled (consumed by the firstboot user service)
[group('Hardware')]
framework-dsp-on:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "framework-dsp-on"
    sudo install -d -m 0755 /var/lib/blueberry
    sudo touch /var/lib/blueberry/dsp.enabled
    bb_ok "DSP marker set — re-login or restart easyeffects to apply"

# Clear the DSP-enabled marker
[group('Hardware')]
framework-dsp-off:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "framework-dsp-off"
    sudo rm -f /var/lib/blueberry/dsp.enabled
    bb_ok "DSP marker cleared"

# Show CalDigit dock status via boltctl (Thunderbolt)
[group('Diagnostics')]
dock-status:
    #!/usr/bin/env bash
    set -eu
    . /usr/lib/blueberry/gum-theme.sh
    bb_header "dock-status"
    if ! command -v boltctl >/dev/null; then
        bb_err "boltctl not installed"
        exit 1
    fi
    if boltctl list 2>/dev/null | grep -q -i "CalDigit"; then
        boltctl list | grep -A6 -i "CalDigit"
        bb_ok "CalDigit dock detected"
    else
        bb_warn "no CalDigit dock detected"
    fi
