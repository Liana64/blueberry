#!/bin/bash
# Enable COPR repos and third-party repos needed by later scripts

# autotiling-rs from COPR
dnf5 -y copr enable ublue-os/packages

# LocalSend COPR
dnf5 -y copr enable fiftydinar/localsend
