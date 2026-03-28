#!/bin/bash
# Set up Flathub repo. Actual app installs happen at first boot via systemd service.

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
