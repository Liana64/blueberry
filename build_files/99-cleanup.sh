#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# drop layering caches (most live on cache mounts; this catches stragglers)
rm -rf /var/lib/dnf /var/cache/dnf /var/cache/rpm-ostree
rm -rf /tmp/* /var/tmp/*

# reset so each install gets a fresh machine-id
:> /etc/machine-id

echo "::endgroup::"
