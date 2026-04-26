#!/usr/bin/env bash
set -ouex pipefail

. /ctx/lib.sh

log "Starting Blueberry image build"

for script in /ctx/[0-9]*.sh; do
    log "==> $(basename "$script")"
    "$script"
done

log "Build complete"
