#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Recipes are copied via system_files; no further action required.
# base-main provides /usr/bin/ujust which sources /usr/share/ublue-os/just/*.just.

echo "::endgroup::"
