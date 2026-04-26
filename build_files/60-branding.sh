#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Branding"

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
