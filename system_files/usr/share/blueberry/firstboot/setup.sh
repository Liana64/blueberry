#!/usr/bin/env bash
# Run once per user. Idempotent.
set -eu

marker="$HOME/.config/blueberry/firstboot.done"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")"

# Add Flathub remote for this user
flatpak remote-add --if-not-exists --user flathub /etc/flatpak/remotes.d/flathub.flatpakrepo

# Install flatpaks
while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    flatpak install --user --noninteractive --or-update flathub "$ref" || true
done < /usr/share/blueberry/flatpaks.list

# Symlink EasyEffects preset into the Flatpak sandbox config
ee_dir="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output"
mkdir -p "$ee_dir"
ln -sf /etc/blueberry/easyeffects/cab-fw.json "$ee_dir/cab-fw.json"

# Switch login shell to zsh
if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh "$USER" || true
fi

touch "$marker"
