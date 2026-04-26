#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Cleanup"

# Remove dnf/rpm metadata caches built during layering
rm -rf /var/lib/dnf /var/cache/dnf /var/cache/rpm-ostree
rm -rf /tmp/* /var/tmp/*

# Reset machine-id so each install gets a fresh one
:> /etc/machine-id

# bootc lint runs in the Containerfile; nothing else needed here.
