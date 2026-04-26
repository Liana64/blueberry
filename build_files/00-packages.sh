#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Layering RPMs"

dnf_install \
    cosign
