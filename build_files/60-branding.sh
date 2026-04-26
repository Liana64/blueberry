#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Activate plymouth theme
plymouth-set-default-theme blueberry

# os-release
# Keep ID=fedora so bootc-image-builder (and other distro-aware tooling)
# recognise this as Fedora and find their built-in def files. Use
# VARIANT_ID for blueberry-specific detection.
fedora_ver="$(rpm -E %fedora)"
cat > /etc/os-release <<EOF
NAME="Blueberry"
PRETTY_NAME="Blueberry ${fedora_ver}"
ID=fedora
ID_LIKE="fedora"
VERSION="${fedora_ver} (Atomic)"
VERSION_ID=${fedora_ver}
VARIANT="Blueberry"
VARIANT_ID=blueberry
HOME_URL="https://github.com/liana64/blueberry"
LOGO=fedora-logo-icon
EOF

echo "::endgroup::"
