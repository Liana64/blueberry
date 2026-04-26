#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Build-time-only Rust toolchain to install crates not packaged for Fedora.
# Binaries land in /usr/bin so they're system-managed; toolchain + cargo
# state are removed afterward to keep the layer slim.
#
# Note: /usr/local on bootc is a symlink to /var/usrlocal — cargo's
# `--root /usr/local` fails because it tries to create the directory.

dnf -y install cargo rust

work=$(mktemp -d)
export CARGO_HOME="$work/cargo-home"
mkdir -p "$CARGO_HOME"

# tealdeer — Rust tldr client (not in F43 repos)
cargo install --locked --root "$work" tealdeer

install -m 0755 "$work/bin/tldr" /usr/bin/tldr
strip /usr/bin/tldr || true

# Remove the toolchain so it's not in the final image
dnf -y remove cargo rust
rm -rf "$work"

echo "::endgroup::"
