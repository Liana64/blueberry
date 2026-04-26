#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Make NM dispatcher script executable
chmod +x /etc/NetworkManager/dispatcher.d/90-wg-autoconnect

# Make MOTD script executable (sourced by /etc/profile, but mark exec for clarity)
chmod +x /etc/profile.d/blueberry-motd.sh

# Dock monitor for CalDigit TS4 sleep-inhibitor
chmod +x /usr/libexec/blueberry/dock-monitor.sh

echo "::endgroup::"
