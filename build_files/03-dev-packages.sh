#!/bin/bash
# Development tools from Fedora repos

dnf5 install -y \
    rust \
    cargo \
    golang \
    neovim \
    python3-neovim \
    shellcheck \
    shfmt \
    gcc \
    gcc-c++ \
    make \
    cmake \
    git \
    gh \
    ansible \
    podman \
    podman-compose

# CLI tools well-packaged in Fedora repos
dnf5 install -y \
    bat \
    eza \
    fd-find \
    fzf \
    ripgrep \
    btop \
    jq \
    tmux \
    age \
    zoxide \
    hexyl \
    procs \
    fastfetch \
    tealdeer \
    git-delta \
    duf \
    dust
