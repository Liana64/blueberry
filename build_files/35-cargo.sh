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

# autotiling-rs — Rust port of autotiling for sway (not on crates.io;
# pinned commit on ammgws/autotiling-rs)
AUTOTILING_RS_REF="59cefd205247aea03d7e7fa26b878deef3b454de"
cargo install --locked --root "$work" \
    --git https://github.com/ammgws/autotiling-rs.git \
    --rev "$AUTOTILING_RS_REF" \
    autotiling-rs

install -m 0755 "$work/bin/tldr"          /usr/bin/tldr
install -m 0755 "$work/bin/autotiling-rs" /usr/bin/autotiling-rs
strip /usr/bin/tldr /usr/bin/autotiling-rs || true

# Remove the toolchain so it's not in the final image
dnf -y remove cargo rust
rm -rf "$work"

echo "::endgroup::"
