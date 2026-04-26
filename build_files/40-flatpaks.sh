#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Flathub remote is shipped under /etc/flatpak/remotes.d/ but bootc's flatpak
# does not auto-import these at install time. Firstboot will run
# `flatpak remote-add` from this file. The list is shipped at
# /usr/share/blueberry/flatpaks.list and also installed at firstboot.

chmod +x /usr/share/blueberry/firstboot/setup.sh

echo "::endgroup::"
