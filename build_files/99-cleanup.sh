#!/bin/bash
# Final cleanup

# Disable COPRs so they don't remain enabled on the final image
#dnf5 -y copr disable ublue-os/packages

# Clean package caches
dnf5 clean all

# Fix SELinux file contexts for anything we copied/modified
restorecon -R /etc/ || true
