#!/usr/bin/env bash
# Hold a sleep inhibitor while a CalDigit TS4 is docked AND authorized.
# Mirrors modules/hardware/laptop.nix in the NixOS dotfiles.
set -euo pipefail

# Wait briefly for boltctl to finish authorizing the device after the udev
# `add` event fires. Without this, the first poll can race the auth handshake
# and see no CalDigit entry at all.
sleep 3

while true; do
    info=$(/usr/bin/boltctl list 2>/dev/null || true)
    # Match only when the CalDigit block is present AND its status reports
    # connected/authorized — `boltctl list` keeps remembering devices that
    # have ever been seen, so a plain grep would never let this script exit.
    if echo "$info" | grep -q "CalDigit" && \
       echo "$info" | grep -A10 "CalDigit" | grep -qE "status:[[:space:]]+(connected|authorized)"; then
        sleep 10
    else
        exit 0
    fi
done
