# Blueberry

An opinionated, atomic [bootc](https://github.com/bootc-dev/bootc) Fedora image for Framework AMD AI 300 series laptops, derived from [`ghcr.io/ublue-os/base-main`](https://github.com/ublue-os/main) and layered with [Sway](https://swaywm.org/).

## What's inside

- **Desktop:** Sway + waybar + mako + rofi (Wayland-only)
- **Login:** greetd + tuigreet on tty1
- **Audio:** PipeWire + WirePlumber + EasyEffects with a Framework speaker preset
- **Security:** SELinux enforcing, Linux audit (anomaly mode), USBGuard, faillock, firewalld, chrony NTS
- **Hardware:** Framework charge limit at 80%, fwupd/fprintd/bolt, CalDigit TS4 dock sleep-inhibitor
- **Apps:** Flatpak-first; CLI host tools layered as RPMs
- **Tooling:** `ujust` for `update`, `verify-image`, `rollback`, `assemble-distrobox`, `toggle-charge-limit`

## Switching to Blueberry

From any bootc system:

```sh
sudo bootc switch ghcr.io/<owner>/blueberry:stable
sudo systemctl reboot
```

On first user login, `blueberry-firstboot.service` installs Flatpaks, symlinks the EasyEffects preset, and switches the login shell to zsh.

## Local development

```sh
just build                  # OCI image (filesystem inspection)
just build-qcow2            # bootable VM disk
just run-vm-qcow2           # boot the qcow2 with full systemd
just spawn-vm               # systemd-vmspawn variant
```

The OCI image build is fast and useful for `podman run --rm <image> <command>` style filesystem checks. systemd, sway, PipeWire, udev, and USBGuard will not function inside a container — use the qcow2 path for end-to-end behavior testing.

## `ujust` commands

| Command | What it does |
|---------|--------------|
| `ujust update` | rpm-ostree update + flatpak update + distrobox upgrade + brew upgrade (if present) |
| `ujust verify-image` | Verifies the running deployment's signature against the embedded cosign key |
| `ujust rollback` | `rpm-ostree rollback` (reboot to apply) |
| `ujust assemble-distrobox` | Creates the default `fedora-toolbox:44` distrobox |
| `ujust toggle-charge-limit` | Switches Framework battery charge limit between 80% and 100% |

## Image signing

Images are signed with [cosign](https://github.com/sigstore/cosign). The public key ships in the image at `/etc/pki/containers/blueberry-cosign.pub` and `/etc/containers/policy.json` requires a valid signature for any pull from `ghcr.io/<owner>/blueberry`.

To verify against a published image:

```sh
cosign verify --key cosign.pub ghcr.io/<owner>/blueberry:stable
```

## Repository contents

- `Containerfile` — base image + system_files COPY + sharded build run
- `build_files/` — sharded build scripts: packages, services, sway, hardware, flatpaks, ujust, branding, cleanup
- `system_files/` — mirrors `/`; copied verbatim onto the image
- `disk_config/` — bootc-image-builder configs (qcow2 disk, GNOME/KDE Anaconda installer)
- `docs/specs/` — design docs
- `docs/plans/` — implementation plans

## Design

See [`docs/specs/2026-04-25-blueberry-design.md`](docs/specs/2026-04-25-blueberry-design.md) for the full design.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
