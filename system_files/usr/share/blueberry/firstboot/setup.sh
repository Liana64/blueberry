#!/usr/bin/env bash
# Run once per user. Idempotent.
set -eu

. /usr/lib/blueberry/gum-theme.sh

marker="$HOME/.config/blueberry/firstboot.done"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")"

bb_header "first-boot setup"

# Add Flathub remote for this user. If this fails (typically: no network yet
# at first login), skip the flatpak install loop entirely rather than aborting
# the whole script — `set -eu` would otherwise kill firstboot before the
# completion marker is written, causing it to retry on every subsequent login.
if gum spin --title "adding flathub remote" -- \
        flatpak remote-add --if-not-exists --user flathub /etc/flatpak/remotes.d/flathub.flatpakrepo; then
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        gum spin --title "flatpak: $ref" -- \
            flatpak install --user --noninteractive --or-update flathub "$ref" || \
            bb_warn "skipped $ref"
    done < /usr/share/blueberry/flatpaks.list
else
    bb_warn "flathub remote-add failed (no network?); skipping flatpak install"
fi

# Symlink EasyEffects preset + convolver IR into the Flatpak sandbox config
ee_root="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects"
mkdir -p "$ee_root/output" "$ee_root/irs"
ln -sf /etc/blueberry/easyeffects/cab-fw.json "$ee_root/output/cab-fw.json"
ln -sf /etc/blueberry/easyeffects/irs/IR_22ms_27dB_5t_15s_0c.irs \
    "$ee_root/irs/IR_22ms_27dB_5t_15s_0c.irs"
bb_step "easyeffects preset + IR linked"

# Offer to switch login shell to zsh. We can't use `chsh` directly here:
# Fedora's /etc/pam.d/chsh requires a password and we'd still be running
# under a user systemd context with no useful auth. Instead delegate to
# `ujust set-default-shell-zsh`, which goes through sudo (works because
# this script runs in a kitty window with a real TTY, see sway/config).
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

touch "$marker"
bb_ok "first-boot complete"
