#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Sway-specific tweaks not handled by system_files COPY land here.
# (currently empty — sway config ships verbatim under system_files/)

echo "::endgroup::"
