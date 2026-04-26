#!/usr/bin/env bash
# Run once per user. Idempotent.
set -eu

. /usr/lib/blueberry/gum-theme.sh

marker="$HOME/.config/blueberry/firstboot.done"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")"

bb_header "first-boot setup"

# Add Flathub remote; on failure (no network yet) skip the install loop and
# do NOT write the marker — the user can retry from the next login.
network_ok=0
if gum spin --title "adding flathub remote" -- \
        flatpak remote-add --if-not-exists --user flathub /etc/flatpak/remotes.d/flathub.flatpakrepo; then
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        gum spin --title "flatpak: $ref" -- \
            flatpak install --user --noninteractive --or-update flathub "$ref" || \
            bb_warn "skipped $ref"
    done < /usr/share/blueberry/flatpaks.list
    network_ok=1
else
    bb_warn "flathub remote-add failed (no network?); skipping flatpak install"
fi

# Symlink EasyEffects preset + convolver IR into the native (RPM) config dir.
ee_root="$HOME/.config/easyeffects"
mkdir -p "$ee_root/output" "$ee_root/irs"
ln -sf /etc/blueberry/easyeffects/cab-fw.json "$ee_root/output/cab-fw.json"
ln -sf /etc/blueberry/easyeffects/irs/IR_22ms_27dB_5t_15s_0c.irs \
    "$ee_root/irs/IR_22ms_27dB_5t_15s_0c.irs"
bb_step "easyeffects preset + IR linked"

# Offer zsh login shell. `chsh` won't work (Fedora's pam.d/chsh demands a
# password). Delegate to `ujust set-default-shell-zsh` which uses sudo;
# works here because we run in a kitty TTY (see sway/config).
if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    if gum confirm "Set login shell to zsh now? (you can change this later with: ujust set-default-shell-zsh)"; then
        ujust set-default-shell-zsh || bb_warn "shell change failed; you can re-run: ujust set-default-shell-zsh"
    else
        bb_warn "skipped shell change; run \`ujust set-default-shell-zsh\` later if you change your mind"
    fi
fi

# Install brew-managed dev tooling (kubectl, helm, talos, LSPs, ...)
# brew-setup.service from base-main provisions /home/linuxbrew/.linuxbrew.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    gum spin --title "brew bundle" -- \
        brew bundle --file=/usr/share/blueberry/Brewfile || \
        bb_warn "brew bundle had issues"
fi

# Only mark complete if network-dependent steps actually ran; otherwise
# leave the marker absent so the next login retries.
if [ "$network_ok" = 1 ]; then
    touch "$marker"
    bb_ok "first-boot complete"
else
    bb_warn "first-boot incomplete (no network); will retry next login"
fi
