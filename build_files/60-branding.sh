#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Activate plymouth theme
plymouth-set-default-theme blueberry

# os-release
cat > /etc/os-release <<'EOF'
NAME="Blueberry"
PRETTY_NAME="Blueberry"
ID=blueberry
ID_LIKE="fedora"
VERSION_ID=44
VARIANT="Atomic"
VARIANT_ID=atomic
HOME_URL="https://github.com/liana64/blueberry"
EOF

echo "::endgroup::"
