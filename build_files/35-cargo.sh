#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Build-time-only Rust toolchain to install crates not packaged for Fedora.
# Crates land in /usr/local/bin so they outlive the toolchain removal below.

dnf -y install cargo rust

CARGO_HOME=/tmp/cargo-home
export CARGO_HOME

mkdir -p "$CARGO_HOME"

# tealdeer — Rust tldr client (not in F43 repos)
cargo install --locked --root /usr/local tealdeer

# autotiling-rs — Rust port of autotiling for sway/i3
cargo install --locked --root /usr/local autotiling-rs

# Strip debuginfo to keep the layer small
strip /usr/local/bin/tldr /usr/local/bin/autotiling-rs || true

# Remove the toolchain so it's not in the final image
dnf -y remove cargo rust
rm -rf "$CARGO_HOME" /usr/local/.crates.toml /usr/local/.crates2.json

echo "::endgroup::"
