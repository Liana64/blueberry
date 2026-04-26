#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

chmod +x /etc/NetworkManager/dispatcher.d/90-wg-autoconnect

# marked exec for clarity; actually sourced by /etc/profile
chmod +x /etc/profile.d/blueberry-motd.sh

# CalDigit TS4 sleep-inhibitor
chmod +x /usr/libexec/blueberry/dock-monitor.sh

echo "::endgroup::"
