#!/usr/bin/env bash
# Run once per user. Idempotent.
set -eu

. /usr/lib/blueberry/gum-theme.sh

marker="$HOME/.config/blueberry/firstboot.done"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")"

bb_header "first-boot setup"

# Add Flathub remote for this user
gum spin --title "adding flathub remote" -- \
    flatpak remote-add --if-not-exists --user flathub /etc/flatpak/remotes.d/flathub.flatpakrepo

# Install flatpaks
while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    gum spin --title "flatpak: $ref" -- \
        flatpak install --user --noninteractive --or-update flathub "$ref" || \
        bb_warn "skipped $ref"
done < /usr/share/blueberry/flatpaks.list

# Symlink EasyEffects preset into the Flatpak sandbox config
ee_dir="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output"
mkdir -p "$ee_dir"
ln -sf /etc/blueberry/easyeffects/cab-fw.json "$ee_dir/cab-fw.json"
bb_step "easyeffects preset linked"

# Switch login shell to zsh
if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh "$USER" || true
    bb_step "login shell -> zsh"
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
