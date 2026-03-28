#!/bin/bash
set -ouex pipefail

for script in /ctx/build_files/[0-9]*.sh; do
    echo "=== Running $(basename "$script") ==="
    source "$script"
done
