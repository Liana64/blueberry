#!/usr/bin/bash
echo "::group:: ===$(basename "$0")==="
set -eoux pipefail

# Activate Fedora's stock 'sssd' authselect profile with the features
# Blueberry needs. authselect renders the profile's templates into
# /etc/pam.d/{system-auth,password-auth,...} and tracks the selection
# so future `authselect apply-changes` runs preserve it.
#
# --force is required because the base image already has a profile
# selected. The select operation is idempotent across rebuilds.
#
# Features:
#   with-faillock     — wire pam_faillock into the auth phase
#   with-fingerprint  — enable pam_fprintd; users opt in via
#                       `ujust enroll-fingerprint`
#
# pam_u2f is intentionally NOT enabled for system login/sudo. Screen
# unlock (swaylock) uses pam_u2f via /etc/pam.d/swaylock, which is
# outside authselect's templated set.

authselect select sssd \
    with-faillock with-fingerprint --force

echo "::endgroup::"
