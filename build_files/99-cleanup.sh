#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# drop layering caches
rm -rf /var/lib/dnf /var/cache/dnf /var/cache/rpm-ostree
rm -rf /tmp/* /var/tmp/*

# reset so each install gets a fresh machine-id
:> /etc/machine-id

# bootc lint runs in the Containerfile; nothing else needed here.

echo "::endgroup::"
