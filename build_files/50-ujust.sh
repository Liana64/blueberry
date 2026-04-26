#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Installing ujust recipes"
# Recipes are copied via system_files; no further action required.
# base-main provides /usr/bin/ujust which sources /usr/share/ublue-os/just/*.just.
