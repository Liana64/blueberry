#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Hardware quirks"

# Make NM dispatcher script executable
chmod +x /etc/NetworkManager/dispatcher.d/90-wg-autoconnect

# Make MOTD script executable (sourced by /etc/profile, but mark exec for clarity)
chmod +x /etc/profile.d/blueberry-motd.sh
