#!/bin/bash
# Deploy /etc/skel dotfiles to an existing user's home directory
# Usage: sudo ./post-install.sh <username>

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

if [ ! -d "$USER_HOME" ]; then
    echo "Home directory $USER_HOME does not exist"
    exit 1
fi

echo "Deploying dotfiles from /etc/skel to $USER_HOME..."

# Copy dotfiles preserving structure, without overwriting existing files
# Use -n (no-clobber) to avoid overwriting user customizations
cp -rn /etc/skel/. "$USER_HOME/"

# Fix ownership
chown -R "$USERNAME:$USERNAME" "$USER_HOME"

# Set zsh as default shell
usermod -s /bin/zsh "$USERNAME"

echo "Done. Log out and back in for changes to take effect."
