#!/usr/bin/bash
echo "::group:: ===$(basename "$0")==="
set -eoux pipefail

# Activate the custom authselect profile shipped under
# /etc/authselect/custom/blueberry/. authselect renders this profile's
# templates into /etc/pam.d/{system-auth,password-auth,...} and tracks
# the selection so future `authselect apply-changes` runs preserve it.
#
# --force is required because the base image already has a profile
# selected ('sssd' by default on Fedora atomic). The select operation
# is idempotent across rebuilds.
#
# Features enabled:
#   with-faillock        — wire pam_faillock into the auth phase
#   with-pam-u2f-2fa     — enable the pam_u2f line we added in
#                          system-auth/password-auth
#   with-fingerprint     — enable the stock pam_fprintd line; users
#                          opt in via `ujust enroll-fingerprint`

authselect select custom/blueberry \
    with-faillock with-pam-u2f-2fa with-fingerprint --force

echo "::endgroup::"
