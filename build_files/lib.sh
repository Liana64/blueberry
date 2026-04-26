#!/usr/bin/env bash
# Shared helpers for build scripts. Source with: . /ctx/lib.sh

set -ouex pipefail

log() {
    printf '\e[1;34m[blueberry]\e[0m %s\n' "$*" >&2
}

dnf_install() {
    dnf5 install -y --setopt=install_weak_deps=False "$@"
}

enable_unit() {
    systemctl enable "$@"
}

disable_unit() {
    systemctl disable "$@" || true
}

mask_unit() {
    systemctl mask "$@"
}
