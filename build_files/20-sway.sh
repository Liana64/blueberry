#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Sway desktop layer:
#   * /etc/sway/config + /etc/sway/config.d/  (system_files/)
#   * /etc/xdg/{waybar,mako,rofi}/            (system_files/)
# Configs are pure static files copied verbatim by the Containerfile, so
# there is nothing to materialize at build time. Helpers under
# /usr/lib/blueberry/waybar/ are made executable by 30-hardware.sh
# alongside the other libexec scripts; this script is intentionally a
# no-op placeholder kept for numbered-shard ordering.

echo "::endgroup::"
