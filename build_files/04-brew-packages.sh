#!/bin/bash
# Install CLI tools via direct binary downloads (pinned versions)
# This replaces Homebrew for a smaller, fully reproducible image.

# Ensure dependencies are available
dnf5 install -y curl tar unzip

INSTALL_DIR="/usr/local/bin"
mkdir -p "$INSTALL_DIR"

# Helper: download and extract a binary from a tarball
install_tar() {
    local name="$1" url="$2" binary="${3:-$1}"
    echo "Installing $name..."
    curl -fsSL "$url" | tar -xz -C /tmp
    install -m 755 "/tmp/$binary" "$INSTALL_DIR/$name"
}

# Helper: download a standalone binary
install_bin() {
    local name="$1" url="$2"
    echo "Installing $name..."
    curl -fsSL -o "$INSTALL_DIR/$name" "$url"
    chmod 755 "$INSTALL_DIR/$name"
}

ARCH="amd64"
ARCH_ALT="x86_64"

# --- K8s tools ---

# kubectl
KUBECTL_VERSION="v1.32.3"
install_bin kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"

# helm
HELM_VERSION="v3.17.1"
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/linux-${ARCH}/helm "$INSTALL_DIR/helm"

# k9s
K9S_VERSION="v0.40.5"
curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/k9s "$INSTALL_DIR/k9s"

# cilium-cli
CILIUM_VERSION="v0.19.2"
curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-${ARCH}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/cilium "$INSTALL_DIR/cilium"

# talosctl
TALOS_VERSION="v1.9.5"
install_bin talosctl "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-${ARCH}"

# talhelper
TALHELPER_VERSION="v3.0.25"
curl -fsSL "https://github.com/budimanjojo/talhelper/releases/download/${TALHELPER_VERSION}/talhelper_linux_${ARCH}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/talhelper "$INSTALL_DIR/talhelper"

# flux
FLUX_VERSION="v2.4.0"
curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_linux_${ARCH}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/flux "$INSTALL_DIR/flux"

# sops
SOPS_VERSION="v3.9.4"
install_bin sops "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}"

# --- CLI tools ---

# lazygit
LAZYGIT_VERSION="0.46.0"
curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH_ALT}.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/lazygit "$INSTALL_DIR/lazygit"

# atuin
ATUIN_VERSION="v18.13.6"
curl -fsSL "https://github.com/atuinsh/atuin/releases/download/${ATUIN_VERSION}/atuin-${ATUIN_VERSION}-${ARCH_ALT}-unknown-linux-musl.tar.gz" | tar -xz -C /tmp --strip-components=1
install -m 755 /tmp/atuin "$INSTALL_DIR/atuin"

# starship
STARSHIP_VERSION="v1.22.1"
curl -fsSL "https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-${ARCH_ALT}-unknown-linux-musl.tar.gz" | tar -xz -C /tmp
install -m 755 /tmp/starship "$INSTALL_DIR/starship"

# yazi
YAZI_VERSION="v25.3.24"
curl -fsSL "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${ARCH_ALT}-unknown-linux-musl.zip" -o /tmp/yazi.zip
unzip -o /tmp/yazi.zip -d /tmp/yazi-extract
install -m 755 /tmp/yazi-extract/yazi-${ARCH_ALT}-unknown-linux-musl/yazi "$INSTALL_DIR/yazi"

# yq
YQ_VERSION="v4.45.1"
install_bin yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}"

# xh
XH_VERSION="v0.24.1"
curl -fsSL "https://github.com/ducaale/xh/releases/download/${XH_VERSION}/xh-${XH_VERSION}-${ARCH_ALT}-unknown-linux-musl.tar.gz" | tar -xz -C /tmp --strip-components=1
install -m 755 /tmp/xh "$INSTALL_DIR/xh"

# Clean up
rm -rf /tmp/linux-${ARCH} /tmp/k9s /tmp/cilium /tmp/talhelper /tmp/flux \
    /tmp/lazygit /tmp/atuin /tmp/starship /tmp/yazi.zip /tmp/yazi-extract \
    /tmp/xh /tmp/yq /tmp/helm /tmp/kubectl /tmp/talosctl /tmp/sops
