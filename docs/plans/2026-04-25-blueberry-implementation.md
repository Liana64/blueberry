# Blueberry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "Blueberry" — an opinionated, atomic Universal Blue/bootc-based Linux image for Framework AMD AI 300 laptops, derived from `ghcr.io/ublue-os/base-main`, layered with Sway, hardened with SELinux/audit/USBGuard, and packaged with a `ujust` command surface.

**Architecture:** A `Containerfile` that pulls `ghcr.io/ublue-os/base-main:stable` and runs a sharded `build_files/` tree (one shell script per concern: `00-packages.sh`, `10-services.sh`, `20-sway.sh`, `30-hardware.sh`, `40-flatpaks.sh`, `50-ujust.sh`, `60-branding.sh`, `99-cleanup.sh`) coordinated by `build.sh`. System config lives in `system_files/` (mirrors `/`). The image is signed with cosign and published to GHCR via the existing `build.yml` workflow; disk artifacts come from `build-disk.yml` + `bootc-image-builder`.

**Tech Stack:** bootc, Fedora 44 (kernel ≥7), rpm-ostree, dnf5, podman, Containerfile, systemd, SELinux, Linux audit, USBGuard, greetd + tuigreet, sway + waybar + mako + rofi, PipeWire + WirePlumber + EasyEffects, NetworkManager + WireGuard, Flatpak, Homebrew, distrobox, cosign, just, bash, Python (for ujust helpers).

**Spec reference:** `docs/specs/2026-04-25-blueberry-design.md`

---

## File Structure

The build is organized so each `build_files/*.sh` script owns one concern, and `system_files/` mirrors the layout it will install on the running system. This makes diffs reviewable and lets us add/remove a concern without touching the rest.

### `build_files/` — RUN at image build

| File | Responsibility |
|------|----------------|
| `build.sh` | Orchestrator. Sources `lib.sh`, sets `set -ouex pipefail`, runs each numbered script in order. |
| `lib.sh` | Tiny helpers (`log()`, `dnf_install()`, `enable_unit()`, `mask_unit()`). |
| `00-packages.sh` | RPM layering via `dnf5 install` (CLI + system tools + drivers + `cosign`). |
| `10-services.sh` | `systemctl enable/disable/mask` for system units. |
| `20-sway.sh` | Install sway/waybar/mako/rofi/greetd, drop greetd config. |
| `30-hardware.sh` | Framework AMD AI 300 quirks (charge limit, fwupd, fprintd, dock sleep-inhibitor, kernel cmdline). |
| `40-flatpaks.sh` | Write `/etc/flatpak/remotes.d/flathub.flatpakrepo` + `/usr/share/blueberry/flatpaks.list`; the actual install runs at firstboot. |
| `50-ujust.sh` | Install `ujust` recipes under `/usr/share/ublue-os/just/`. |
| `60-branding.sh` | Plymouth theme `blueberry`, `/etc/os-release`, MOTD, wallpaper assets. |
| `99-cleanup.sh` | `rpm-ostree cleanup`, `bootc container lint`, prune docs. |

### `system_files/` — COPY verbatim into image at `/`

| Path | Purpose |
|------|---------|
| `system_files/etc/containers/policy.json` | Cosign-required policy for blueberry image. |
| `system_files/etc/pki/containers/blueberry-cosign.pub` | Embedded pubkey (copied from repo `cosign.pub`). |
| `system_files/etc/greetd/config.toml` | tuigreet command. |
| `system_files/etc/audit/rules.d/00-blueberry.rules` | Anomaly-mode audit baseline (0 rules). |
| `system_files/etc/usbguard/usbguard-daemon.conf` | LinuxAudit backend, IPCAllowedGroups=wheel. |
| `system_files/etc/security/faillock.conf` | Lockout after 5 failures, 15 min. |
| `system_files/etc/firewalld/zones/FedoraWorkstation.xml` | Open port 53317 (KDE Connect / LocalSend). |
| `system_files/etc/chrony.conf` | NTS servers (time.cloudflare.com, time.nist.gov, nts.netnod.se). |
| `system_files/etc/systemd/logind.conf.d/10-blueberry.conf` | `HandleLidSwitch=suspend`. |
| `system_files/etc/systemd/system/inhibit-sleep-when-docked.service` | Inhibits suspend while CalDigit TS4 attached. |
| `system_files/etc/systemd/system/lock-before-sleep.service` | Locks sway via `swaylock -f` before suspend. |
| `system_files/etc/systemd/system/blueberry-firstboot.service` | Runs once per user on first login. |
| `system_files/etc/systemd/system/framework-charge-limit.service` | Writes `/sys/class/power_supply/BAT1/charge_control_end_threshold`. |
| `system_files/etc/NetworkManager/conf.d/10-blueberry.conf` | `keyfile.unmanaged-devices=interface-name:wg0`, connectivity check on. |
| `system_files/etc/NetworkManager/dispatcher.d/90-wg-autoconnect` | Brings `wg0` up on `connectivity-change`. |
| `system_files/etc/wireplumber/wireplumber.conf.d/51-default-nodes.conf` | `default-nodes.auto-switch = true`. |
| `system_files/etc/udev/rules.d/70-caldigit-ts4.rules` | Pulled from NixOS `modules/hardware/laptop.nix`. |
| `system_files/etc/udev/rules.d/70-yubikey.rules` | Vendored from `yubikey-personalization`. |
| `system_files/etc/blueberry/easyeffects/cab-fw.json` | Gracefu's Edits DSP preset. |
| `system_files/etc/profile.d/blueberry-motd.sh` | Per-session MOTD using `XDG_SESSION_ID` marker. |
| `system_files/usr/share/blueberry/flatpaks.list` | One Flatpak ref per line. |
| `system_files/usr/share/blueberry/firstboot/setup.sh` | flatpak install, chsh, easyeffects symlink. |
| `system_files/usr/share/ublue-os/just/60-blueberry.just` | All `ujust` recipes (`update`, `verify-image`, `rollback`, `assemble-distrobox`, `toggle-charge-limit`). |
| `system_files/usr/share/plymouth/themes/blueberry/` | Plymouth theme files. |
| `system_files/usr/share/backgrounds/blueberry/flower.png` | Wallpaper (copied from dotfiles). |

### Repo-root config

| File | Change |
|------|--------|
| `Containerfile` | `FROM ghcr.io/ublue-os/base-main:stable`; mount build context, run `build.sh`, lint. |
| `Justfile` | Set `image_name := "blueberry"`. |
| `.github/workflows/build.yml` | Bump `IMAGE_NAME=blueberry`, `DEFAULT_TAG=stable`. |
| `.github/workflows/build-disk.yml` | Same name/tag bumps. |
| `disk_config/iso.toml` | Point at `ghcr.io/<owner>/blueberry:stable`. |
| `cosign.pub` | Generated locally, committed; `.key` stays as repo secret. |

### Out-of-scope (separate repo)

User dotfiles (kitty, nvim, zsh, starship, atuin, sway keybinds, waybar style, mako, rofi theme, firefox profile, GPG, k9s, anki) live in a chezmoi repo. This plan installs the *binaries* and *system-level* configs only.

---

## Phase 1 — Foundation

Scaffold the build pipeline and prove the image builds locally before touching real config.

### Task 1.1: Switch base image and add build-script orchestrator

**Files:**
- Modify: `Containerfile`
- Create: `build_files/lib.sh`
- Modify: `build_files/build.sh`

- [ ] **Step 1: Read current Containerfile**

Run: `cat Containerfile`
Confirm `FROM ghcr.io/ublue-os/bazzite:stable` is on line 6.

- [ ] **Step 2: Replace base image and add OCI labels**

Edit `Containerfile` line 6 from:
```
FROM ghcr.io/ublue-os/bazzite:stable
```
to:
```
FROM ghcr.io/ublue-os/base-main:stable

LABEL org.opencontainers.image.title="blueberry"
LABEL org.opencontainers.image.description="Opinionated atomic Fedora image for Framework AMD AI 300 laptops"
LABEL org.opencontainers.image.source="https://github.com/liana64/blueberry"
LABEL org.opencontainers.image.licenses="Apache-2.0"
```

- [ ] **Step 3: Create `build_files/lib.sh`**

```bash
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
```

- [ ] **Step 4: Rewrite `build_files/build.sh` as orchestrator**

```bash
#!/usr/bin/env bash
set -ouex pipefail

. /ctx/lib.sh

log "Starting Blueberry image build"

for script in /ctx/[0-9]*.sh; do
    log "==> $(basename "$script")"
    "$script"
done

log "Build complete"
```

- [ ] **Step 5: Make scripts executable in repo**

Run: `chmod +x build_files/build.sh build_files/lib.sh`
Expected: no output.

- [ ] **Step 6: Create placeholder numbered scripts**

For each of `00-packages.sh 10-services.sh 20-sway.sh 30-hardware.sh 40-flatpaks.sh 50-ujust.sh 60-branding.sh 99-cleanup.sh`, write to `build_files/<name>`:
```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "TODO: $(basename "$0")"
```
Then `chmod +x build_files/[0-9]*.sh`.

- [ ] **Step 7: Build locally to verify scaffolding works**

Run: `just build blueberry latest`
Expected: image builds, all 8 placeholder scripts log "TODO: …", `bootc container lint` passes.

- [ ] **Step 8: Commit**

```bash
git add Containerfile build_files/
git commit -m "feat: switch base to base-main, add sharded build orchestrator"
```

### Task 1.2: Wire up `system_files/` copy mechanism

**Files:**
- Modify: `Containerfile`
- Create: `system_files/.gitkeep`

- [ ] **Step 1: Add system_files COPY layer to Containerfile**

Insert before the `RUN --mount=type=bind,from=ctx,...` block:
```
# System files: copy the entire tree verbatim onto the image
COPY system_files/ /
```

- [ ] **Step 2: Create empty system_files tree**

Run: `mkdir -p system_files && touch system_files/.gitkeep`

- [ ] **Step 3: Build to confirm COPY succeeds with empty tree**

Run: `just build blueberry latest`
Expected: build passes; `bootc container lint` passes.

- [ ] **Step 4: Commit**

```bash
git add Containerfile system_files/.gitkeep
git commit -m "feat: add system_files/ COPY layer"
```

### Task 1.3: Rename image in workflows and Justfile

**Files:**
- Modify: `Justfile` (line 1)
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/build-disk.yml`
- Modify: `disk_config/iso.toml` (or whichever `*.toml` is referenced by `build-disk.yml`)

- [ ] **Step 1: Read current Justfile line 1**

Run: `head -1 Justfile`
Expected: `image_name := "image-template"` or similar.

- [ ] **Step 2: Set `image_name := "blueberry"` in Justfile**

Edit line 1 to: `image_name := "blueberry"`

- [ ] **Step 3: Update workflow env vars**

In `.github/workflows/build.yml`, set `IMAGE_NAME: blueberry` and `DEFAULT_TAG: stable` in the env block. In `.github/workflows/build-disk.yml`, set the same plus `IMAGE_REGISTRY: ghcr.io/${{ github.repository_owner }}`.

- [ ] **Step 4: Update `disk_config/*.toml` image reference**

Read each toml file under `disk_config/`. For each one that contains a container image reference, replace with `ghcr.io/<owner>/blueberry:stable` (use a placeholder `OWNER` if the actual owner isn't yet known).

- [ ] **Step 5: Local rebuild sanity check**

Run: `just build`
Expected: builds with new name `localhost/blueberry:latest`.

- [ ] **Step 6: Commit**

```bash
git add Justfile .github/workflows/build.yml .github/workflows/build-disk.yml disk_config/
git commit -m "feat: rename image to blueberry"
```

### Task 1.4: Cosign keypair + policy

**Files:**
- Create: `cosign.pub` (committed)
- Create: `system_files/etc/pki/containers/blueberry-cosign.pub`
- Create: `system_files/etc/containers/policy.json`
- Modify: `build_files/00-packages.sh` (add `cosign`)

- [ ] **Step 1: Generate cosign keypair**

Run from repo root: `COSIGN_PASSWORD="" cosign generate-key-pair`
Expected: produces `cosign.key` (DO NOT COMMIT) and `cosign.pub`.

- [ ] **Step 2: Confirm `.gitignore` excludes `cosign.key`**

Read `.gitignore`. If `cosign.key` is missing, add it on its own line.

- [ ] **Step 3: Mirror pubkey into system_files**

```bash
mkdir -p system_files/etc/pki/containers
cp cosign.pub system_files/etc/pki/containers/blueberry-cosign.pub
```

- [ ] **Step 4: Write `system_files/etc/containers/policy.json`**

```json
{
    "default": [{"type": "insecureAcceptAnything"}],
    "transports": {
        "docker": {
            "ghcr.io/liana64/blueberry": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "/etc/pki/containers/blueberry-cosign.pub",
                    "signedIdentity": {"type": "matchRepository"}
                }
            ]
        }
    }
}
```
(Replace `liana64` with the actual GHCR org/user.)

- [ ] **Step 5: Add `cosign` to RPM list in `00-packages.sh`**

Replace the placeholder body with:
```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Layering RPMs"

dnf_install \
    cosign
```
(More packages added in Phase 2.)

- [ ] **Step 6: Build and verify pubkey is present**

Run: `just build`
Then: `podman run --rm localhost/blueberry:latest cat /etc/pki/containers/blueberry-cosign.pub`
Expected: matches `cosign.pub`.

- [ ] **Step 7: Commit (cosign.key NOT staged)**

```bash
git status  # confirm cosign.key is NOT listed under "to be committed"
git add cosign.pub system_files/etc/pki/ system_files/etc/containers/ build_files/00-packages.sh .gitignore
git commit -m "feat: cosign keypair, policy, RPM layering scaffold"
```

- [ ] **Step 8: Upload `cosign.key` to GHCR repo secrets**

Run: `gh secret set SIGNING_SECRET < cosign.key`
Expected: `✓ Set Actions secret SIGNING_SECRET for <owner>/<repo>`.
(If `gh` is not authenticated, ask the user to run this manually — see README.)

---

## Phase 2 — Security baseline

SELinux enforcing comes from base-main; this phase layers audit, USBGuard, faillock, firewalld, chrony NTS, greetd, and the host CLI tools.

### Task 2.1: RPM layering — host CLI + system tools

**Files:**
- Modify: `build_files/00-packages.sh`

- [ ] **Step 1: Expand RPM list to full host CLI surface**

Replace `00-packages.sh` body's `dnf_install` block with:
```bash
dnf_install \
    cosign \
    audit \
    usbguard \
    pam \
    faillock \
    firewalld \
    chrony \
    greetd \
    greetd-tuigreet \
    sway \
    swaylock \
    swayidle \
    swaybg \
    waybar \
    mako \
    rofi \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    playerctl \
    polkit-gnome \
    pipewire \
    pipewire-pulseaudio \
    pipewire-jack-audio-connection-kit \
    wireplumber \
    easyeffects \
    NetworkManager-wifi \
    NetworkManager-wireguard \
    wireguard-tools \
    bluez \
    blueman \
    fwupd \
    fprintd \
    bolt \
    pcsc-lite \
    pcsc-lite-ccid \
    yubikey-personalization \
    yubikey-manager \
    flatpak \
    distrobox \
    podman \
    just \
    git \
    vim \
    zsh \
    util-linux-user \
    bind-utils \
    bc \
    perf \
    inotify-tools \
    lm_sensors \
    smartmontools \
    dmidecode \
    ethtool \
    hdparm \
    nvme-cli \
    sbctl \
    sysstat \
    tcpdump \
    wireshark-cli \
    udisks2 \
    gvfs \
    devmon \
    google-noto-fonts-common \
    google-noto-emoji-fonts \
    jetbrains-mono-fonts \
    cabin-fonts \
    plymouth \
    plymouth-plugin-script
```

- [ ] **Step 2: Build and check size**

Run: `just build`
Expected: build succeeds; `podman image inspect localhost/blueberry:latest --format '{{.Size}}'` returns a value (informational only — no hard threshold).

- [ ] **Step 3: Commit**

```bash
git add build_files/00-packages.sh
git commit -m "feat: layer host CLI, desktop, and security RPMs"
```

### Task 2.2: Audit baseline (anomaly mode, 0 rules)

**Files:**
- Create: `system_files/etc/audit/rules.d/00-blueberry.rules`
- Create: `system_files/etc/audit/auditd.conf` (minimal override)

- [ ] **Step 1: Write empty audit rules file**

```
# Blueberry audit baseline: anomaly mode, no allowlist rules.
# Auditd runs and logs anomalies (e.g., AVC denials) without explicit watches.
```

- [ ] **Step 2: Write `auditd.conf`**

Only override what differs from upstream Fedora:
```
log_file = /var/log/audit/audit.log
log_format = ENRICHED
flush = INCREMENTAL_ASYNC
freq = 50
max_log_file = 50
num_logs = 5
disp_qos = lossy
name_format = HOSTNAME
```

- [ ] **Step 3: Add audit enable to `10-services.sh`**

Replace placeholder body:
```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Enabling/disabling system units"

enable_unit auditd.service
```

- [ ] **Step 4: Build and verify auditd is enabled**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled auditd.service`
Expected: `enabled`.

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/audit/ build_files/10-services.sh
git commit -m "feat: enable auditd in anomaly mode"
```

### Task 2.3: USBGuard with LinuxAudit backend

**Files:**
- Create: `system_files/etc/usbguard/usbguard-daemon.conf`
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Write usbguard daemon config**

```
RuleFile=/etc/usbguard/rules.conf
ImplicitPolicyTarget=block
PresentDevicePolicy=apply-policy
PresentControllerPolicy=keep
InsertedDevicePolicy=apply-policy
RestoreControllerDeviceState=false
DeviceManagerBackend=uevent
IPCAllowedUsers=root
IPCAllowedGroups=wheel
IPCAccessControlFiles=/etc/usbguard/IPCAccessControl.d/
DeviceRulesWithPort=false
AuditBackend=LinuxAudit
AuditFilePath=/var/log/usbguard/usbguard-audit.log
HidePII=false
```

- [ ] **Step 2: Enable usbguard + companion services**

Append to `10-services.sh` after `enable_unit auditd.service`:
```bash
enable_unit usbguard.service
enable_unit usbguard-dbus.service
enable_unit udisks2.service
enable_unit devmon@.service || true   # template, started per-user later
```

- [ ] **Step 3: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled usbguard.service`
Expected: `enabled`.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/usbguard/ build_files/10-services.sh
git commit -m "feat: USBGuard with LinuxAudit backend, IPC for wheel"
```

### Task 2.4: faillock + firewalld + chrony NTS

**Files:**
- Create: `system_files/etc/security/faillock.conf`
- Create: `system_files/etc/firewalld/zones/FedoraWorkstation.xml`
- Create: `system_files/etc/chrony.conf`
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Write `faillock.conf`**

```
deny = 5
unlock_time = 900
fail_interval = 900
silent
```

- [ ] **Step 2: Write firewalld zone with port 53317**

```xml
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Fedora Workstation</short>
  <description>Default zone for Blueberry: SSH allowed for sshd; LocalSend on 53317.</description>
  <service name="dhcpv6-client"/>
  <service name="mdns"/>
  <service name="samba-client"/>
  <service name="ssh"/>
  <port port="53317" protocol="tcp"/>
  <port port="53317" protocol="udp"/>
</zone>
```

- [ ] **Step 3: Write `chrony.conf` with NTS sources**

```
server time.cloudflare.com iburst nts
server time.nist.gov iburst nts
server nts.netnod.se iburst nts
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
keyfile /etc/chrony.keys
ntsdumpdir /var/lib/chrony
leapsectz right/UTC
logdir /var/log/chrony
```

- [ ] **Step 4: Enable units**

Append to `10-services.sh`:
```bash
enable_unit firewalld.service
enable_unit chronyd.service
```

- [ ] **Step 5: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest sh -c 'cat /etc/security/faillock.conf | grep deny'`
Expected: `deny = 5`.

- [ ] **Step 6: Commit**

```bash
git add system_files/etc/security/ system_files/etc/firewalld/ system_files/etc/chrony.conf build_files/10-services.sh
git commit -m "feat: faillock, firewalld with port 53317, chrony NTS"
```

### Task 2.5: greetd + tuigreet

**Files:**
- Create: `system_files/etc/greetd/config.toml`
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Write greetd config**

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-user-session --asterisks --cmd sway"
user = "greeter"
```

- [ ] **Step 2: Enable greetd, disable gdm if present**

Append to `10-services.sh`:
```bash
enable_unit greetd.service
systemctl set-default graphical.target
disable_unit gdm.service
mask_unit gdm.service
```

- [ ] **Step 3: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled greetd.service`
Expected: `enabled`.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/greetd/ build_files/10-services.sh
git commit -m "feat: greetd + tuigreet as login manager"
```

---

## Phase 3 — Desktop layer

System-level sway/PipeWire/NetworkManager wiring. Per-user sway config (keybinds, waybar layout) is dotfiles territory and lives in chezmoi.

### Task 3.1: WirePlumber default-nodes auto-switch

**Files:**
- Create: `system_files/etc/wireplumber/wireplumber.conf.d/51-default-nodes.conf`

- [ ] **Step 1: Write WirePlumber drop-in**

```
monitor.alsa.rules = [
  {
    matches = [ { node.name = "~alsa_output.*" } ]
    actions = {
      update-props = {
        node.pause-on-idle = false
      }
    }
  }
]

wireplumber.settings = {
  default-nodes.auto-switch = true
}
```

- [ ] **Step 2: Build and verify file present**

Run: `just build && podman run --rm localhost/blueberry:latest cat /etc/wireplumber/wireplumber.conf.d/51-default-nodes.conf | head -3`

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/wireplumber/
git commit -m "feat: WirePlumber default-nodes auto-switch"
```

### Task 3.2: NetworkManager + WireGuard auto-connect

**Files:**
- Create: `system_files/etc/NetworkManager/conf.d/10-blueberry.conf`
- Create: `system_files/etc/NetworkManager/dispatcher.d/90-wg-autoconnect`

- [ ] **Step 1: Write NM main config drop-in**

```
[main]
dns=default

[connectivity]
uri=http://fedoraproject.org/static/hotspot.txt
interval=300

[keyfile]
unmanaged-devices=interface-name:wg0
```

- [ ] **Step 2: Write NM dispatcher script**

```bash
#!/usr/bin/env bash
# 90-wg-autoconnect: bring wg0 up when connectivity becomes full
set -eu

iface="$1"
event="$2"

if [ "$event" != "connectivity-change" ]; then
    exit 0
fi

if [ "$CONNECTIVITY_STATE" = "FULL" ]; then
    if ! /usr/bin/wg show wg0 >/dev/null 2>&1; then
        /usr/bin/wg-quick up wg0 || true
    fi
else
    if /usr/bin/wg show wg0 >/dev/null 2>&1; then
        /usr/bin/wg-quick down wg0 || true
    fi
fi
```

- [ ] **Step 3: Set executable bit**

Add to `build_files/30-hardware.sh` (replacing placeholder):
```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Hardware quirks"

chmod +x /etc/NetworkManager/dispatcher.d/90-wg-autoconnect
```

- [ ] **Step 4: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest test -x /etc/NetworkManager/dispatcher.d/90-wg-autoconnect && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/NetworkManager/ build_files/30-hardware.sh
git commit -m "feat: NM unmanaged wg0 + dispatcher auto-connect"
```

### Task 3.3: Plymouth blueberry theme + branding

**Files:**
- Create: `system_files/usr/share/plymouth/themes/blueberry/blueberry.plymouth`
- Create: `system_files/usr/share/plymouth/themes/blueberry/blueberry.script`
- Create: `system_files/usr/share/plymouth/themes/blueberry/logo.png` (placeholder)
- Modify: `build_files/60-branding.sh`

- [ ] **Step 1: Write `blueberry.plymouth`**

```
[Plymouth Theme]
Name=Blueberry
Description=Blueberry boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/blueberry
ScriptFile=/usr/share/plymouth/themes/blueberry/blueberry.script
```

- [ ] **Step 2: Write minimal `blueberry.script`**

```
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);

fun refresh_callback() { }
Plymouth.SetRefreshFunction(refresh_callback);
```

- [ ] **Step 3: Drop in a placeholder logo**

For now, copy any 256x256 PNG (e.g., `cp /usr/share/icons/hicolor/256x256/apps/fedora-logo-icon.png system_files/usr/share/plymouth/themes/blueberry/logo.png` outside the build, OR write a 1px transparent PNG via `printf`).

- [ ] **Step 4: Wire `60-branding.sh`**

```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Branding"

# Activate plymouth theme
plymouth-set-default-theme blueberry

# os-release
cat > /etc/os-release <<'EOF'
NAME="Blueberry"
PRETTY_NAME="Blueberry"
ID=blueberry
ID_LIKE="fedora"
VERSION_ID=44
VARIANT="Atomic"
VARIANT_ID=atomic
HOME_URL="https://github.com/liana64/blueberry"
EOF
```

- [ ] **Step 5: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest plymouth-set-default-theme`
Expected: `blueberry`.

- [ ] **Step 6: Commit**

```bash
git add system_files/usr/share/plymouth/ build_files/60-branding.sh
git commit -m "feat: blueberry plymouth theme + os-release"
```

### Task 3.4: Per-session MOTD

**Files:**
- Create: `system_files/etc/profile.d/blueberry-motd.sh`

- [ ] **Step 1: Write the MOTD script**

```bash
#!/usr/bin/env bash
# Show MOTD once per login session, keyed on XDG_SESSION_ID.

[ -z "${XDG_SESSION_ID:-}" ] && return 0

marker="/run/user/${UID}/blueberry-motd-${XDG_SESSION_ID}"
[ -e "$marker" ] && return 0
mkdir -p "$(dirname "$marker")" 2>/dev/null || return 0
touch "$marker"

cat <<'EOF'
  ____  _            _
 | __ )| |_   _  ___| |__   ___ _ __ _ __ _   _
 |  _ \| | | | |/ _ \ '_ \ / _ \ '__| '__| | | |
 | |_) | | |_| |  __/ |_) |  __/ |  | |  | |_| |
 |____/|_|\__,_|\___|_.__/ \___|_|  |_|   \__, |
                                          |___/
 Try `ujust` for things to do, `ujust update` to roll forward.
EOF
```

- [ ] **Step 2: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest sh -c 'XDG_SESSION_ID=test UID=0 . /etc/profile.d/blueberry-motd.sh'`
Expected: ASCII art prints once.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/profile.d/blueberry-motd.sh
git commit -m "feat: per-session MOTD using XDG_SESSION_ID marker"
```

---

## Phase 4 — Hardware (Framework AMD AI 300)

### Task 4.1: Framework charge limit service

**Files:**
- Create: `system_files/etc/systemd/system/framework-charge-limit.service`
- Modify: `build_files/30-hardware.sh`

- [ ] **Step 1: Write the unit**

```ini
[Unit]
Description=Set Framework battery charge limit to 80%
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/sh -c 'echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: Enable in `10-services.sh`**

Append: `enable_unit framework-charge-limit.service`

- [ ] **Step 3: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled framework-charge-limit.service`
Expected: `enabled`.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/systemd/system/framework-charge-limit.service build_files/10-services.sh
git commit -m "feat: framework charge limit at 80%"
```

### Task 4.2: CalDigit TS4 dock sleep-inhibitor

**Files:**
- Create: `system_files/etc/udev/rules.d/70-caldigit-ts4.rules`
- Create: `system_files/etc/systemd/system/inhibit-sleep-when-docked.service`
- Create: `system_files/usr/libexec/blueberry/dock-monitor.sh`
- Modify: `build_files/30-hardware.sh`

- [ ] **Step 1: Write the udev rule (taken from NixOS `modules/hardware/laptop.nix`)**

```
ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{vendor_name}=="CalDigit, Inc.", TAG+="systemd", ENV{SYSTEMD_WANTS}="inhibit-sleep-when-docked.service"
ACTION=="remove", SUBSYSTEM=="thunderbolt", ATTR{vendor_name}=="CalDigit, Inc.", RUN+="/bin/systemctl stop inhibit-sleep-when-docked.service"
```

- [ ] **Step 2: Write monitor script**

```bash
#!/usr/bin/env bash
# Poll boltctl; while a CalDigit TS4 is docked, hold a sleep inhibitor.
set -eu
while /usr/bin/boltctl list 2>/dev/null | grep -q "CalDigit"; do
    sleep 30
done
```

- [ ] **Step 3: Write the unit**

```ini
[Unit]
Description=Inhibit suspend while CalDigit TS4 is docked
StopWhenUnneeded=yes

[Service]
Type=simple
ExecStart=/usr/bin/systemd-inhibit --what=sleep --who=blueberry --why="Docked to TS4" --mode=block /usr/libexec/blueberry/dock-monitor.sh
```

- [ ] **Step 4: chmod in 30-hardware.sh**

Append: `chmod +x /usr/libexec/blueberry/dock-monitor.sh`

- [ ] **Step 5: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest test -x /usr/libexec/blueberry/dock-monitor.sh && echo OK`
Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add system_files/etc/udev/rules.d/70-caldigit-ts4.rules system_files/etc/systemd/system/inhibit-sleep-when-docked.service system_files/usr/libexec/blueberry/dock-monitor.sh build_files/30-hardware.sh
git commit -m "feat: inhibit sleep while CalDigit TS4 is docked"
```

### Task 4.3: Lock-before-sleep + logind

**Files:**
- Create: `system_files/etc/systemd/system/lock-before-sleep.service`
- Create: `system_files/etc/systemd/logind.conf.d/10-blueberry.conf`

- [ ] **Step 1: Write logind drop-in**

```
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
```

- [ ] **Step 2: Write lock-before-sleep unit**

```ini
[Unit]
Description=Lock sway sessions before suspend
Before=sleep.target

[Service]
Type=forking
ExecStart=/usr/bin/sh -c 'for u in $(loginctl list-users --no-legend | awk "{print \$2}"); do runuser -l "$u" -c "swaylock -f" || true; done'

[Install]
WantedBy=sleep.target
```

- [ ] **Step 3: Enable in `10-services.sh`**

Append: `enable_unit lock-before-sleep.service`

- [ ] **Step 4: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest cat /etc/systemd/logind.conf.d/10-blueberry.conf`
Expected: contains `HandleLidSwitch=suspend`.

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/systemd/ build_files/10-services.sh
git commit -m "feat: lock-before-sleep + logind lid handling"
```

### Task 4.4: Yubikey udev + pcscd

**Files:**
- Create: `system_files/etc/udev/rules.d/70-yubikey.rules`
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Write udev rules** (vendored from `yubikey-personalization`; trim to U2F + OTP modes)

```
# Yubikey U2F + OTP
SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0010|0110|0111|0114|0116|0120|0200|0211|0401|0402|0403|0404|0405|0406|0407|0410", TAG+="uaccess", GROUP="wheel", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", TAG+="uaccess", GROUP="wheel", MODE="0660"
```

- [ ] **Step 2: Enable pcscd**

Append to `10-services.sh`: `enable_unit pcscd.service`

- [ ] **Step 3: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled pcscd.service`
Expected: `enabled`.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/udev/rules.d/70-yubikey.rules build_files/10-services.sh
git commit -m "feat: yubikey udev + pcscd"
```

### Task 4.5: Bluetooth disabled at boot

**Files:**
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Disable bluetooth at boot**

Append:
```bash
disable_unit bluetooth.service
```

- [ ] **Step 2: Drop hardware default `AutoEnable`**

Create `system_files/etc/bluetooth/main.conf` with:
```
[Policy]
AutoEnable=false
```

- [ ] **Step 3: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest systemctl is-enabled bluetooth.service`
Expected: `disabled`.

- [ ] **Step 4: Commit**

```bash
git add build_files/10-services.sh system_files/etc/bluetooth/
git commit -m "feat: bluetooth disabled at boot, waybar can toggle"
```

### Task 4.6: EasyEffects DSP preset (system file, user symlink at firstboot)

**Files:**
- Create: `system_files/etc/blueberry/easyeffects/cab-fw.json`

- [ ] **Step 1: Fetch the Gracefu's Edits preset**

The original NixOS config sources `inputs.framework-dsp`. For the bootc image, vendor the JSON file directly: download from https://github.com/Pa3cio/framework-dsp Gracefu's Edits release and save as `system_files/etc/blueberry/easyeffects/cab-fw.json`.

(If the file isn't immediately available, write a minimal placeholder JSON `{"output": {"plugins_order": []}}` and TODO a follow-up to vendor the real preset. Engineer should ask the user where to source the preset if uncertain.)

- [ ] **Step 2: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest test -f /etc/blueberry/easyeffects/cab-fw.json && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/blueberry/
git commit -m "feat: EasyEffects DSP preset for Framework speakers"
```

---

## Phase 5 — Apps & Flatpaks

### Task 5.1: Flathub remote + flatpak list

**Files:**
- Create: `system_files/etc/flatpak/remotes.d/flathub.flatpakrepo`
- Create: `system_files/usr/share/blueberry/flatpaks.list`
- Modify: `build_files/40-flatpaks.sh`

- [ ] **Step 1: Write Flathub repo file**

```
[Flatpak Repo]
Title=Flathub
Url=https://dl.flathub.org/repo/
Homepage=https://flathub.org/
Comment=Central repository of Flatpak applications
Description=Central repository of Flatpak applications
Icon=https://dl.flathub.org/repo/logo.svg
GPGKey=mQINBFlD2sABEADsiUZUOYBg1UdDaWkEdJYkTSZD68214m8Q1fbrP5AptaUfCl8KYKFMNoAJRBXn9FbE6q6VBzghHXj/rSnA8WPnkbaEWR7xltOqzB1yHpCQ1l8xSfH5N02DMUBSRtD/rOYsBKbaJcOgW0K3JKvkWiGI67SE6CC2Fk2GxAiQsyd5l1IGusbE/Hv8YDGWWAA1FXNCvc6wNjxNvc7kfm5w2VSoEy7Jr/etmtFGLj+2aLwOTRzpGGziuVsKnaerHpmLjJsWO5w+XzrFhfCM+EM8u7PvW9chMKbjjMP/BbqxXFpYwgM/6tsxAOC1zR9PA9Vq8mwXKb2MeHAxV+G6QQiU//PA10NSwMm5GQ8bj7vbiSAxaB+SuMlKEKB8m9i/lOnsYx6tJVNGcYIzWmkUOoI8nuZoJiJOjy5gUIN8bdOyuWDcGKv2DSfuT6byPDdBvLfkZbYCABaCk1AgZ7Nu+0okGL3R8L8Y7mZWjzRtaiSarWvcBb8hKhOpAlpUYiTTM1uH40YTWE2dXKZykSZ5VQAqAul/QcWSZUg6n+QXh4uOJL8mEUtuabTSp9bX/0u8WO+22aSBKbGcKM8U9TtmgD3v+UE0kbW0gHUYWOhUyrbrqsHM4ulnVPrgIdkZx6J/3I+QRqSXqo/+ULP9jc3R6Zr39c2pK7rTgQGCe49nWxZ8jpkpSTcLulOSrcvfDRtY1B+KnPwARAQABtCFGbGF0aHViIFJlcG8gPGZsYXRodWJAZmxhdGh1Yi5vcmc+
```

(This is the standard Flathub repo file from `flathub.org/repo/flathub.flatpakrepo` — engineer: download with `curl -o system_files/etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo` rather than typing it.)

- [ ] **Step 2: Write the flatpak list (from NixOS `modules/linux/flatpak.nix`)**

```
app/org.mozilla.firefox/x86_64/stable
app/org.mozilla.Thunderbird/x86_64/stable
app/com.bitwarden.desktop/x86_64/stable
app/com.discordapp.Discord/x86_64/stable
app/dev.vencord.Vesktop/x86_64/stable
app/im.riot.Riot/x86_64/stable
app/org.signal.Signal/x86_64/stable
app/md.obsidian.Obsidian/x86_64/stable
app/com.github.IsmaelMartinez.teams_for_linux/x86_64/stable
app/us.zoom.Zoom/x86_64/stable
app/com.slack.Slack/x86_64/stable
app/io.github.alainm23.planify/x86_64/stable
app/com.belmoussaoui.Authenticator/x86_64/stable
app/com.spotify.Client/x86_64/stable
app/sh.cider.Cider/x86_64/stable
app/com.github.wwmm.easyeffects/x86_64/stable
app/org.gimp.GIMP/x86_64/stable
app/org.inkscape.Inkscape/x86_64/stable
app/org.kde.krita/x86_64/stable
app/org.libreoffice.LibreOffice/x86_64/stable
app/com.jgraph.drawio.desktop/x86_64/stable
app/io.podman_desktop.PodmanDesktop/x86_64/stable
app/io.dbeaver.DBeaverCommunity/x86_64/stable
app/com.brave.Browser/x86_64/stable
app/io.github.kukuruzka165.materialgram/x86_64/stable
app/org.qbittorrent.qBittorrent/x86_64/stable
app/org.localsend.localsend_app/x86_64/stable
app/ch.protonmail.protonmail-bridge/x86_64/stable
```

- [ ] **Step 3: Wire `40-flatpaks.sh`**

```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Flatpak setup"

# Flathub remote is shipped under /etc/flatpak/remotes.d/ but bootc's flatpak
# does not auto-import these at install time. Firstboot will do `flatpak remote-add`
# from this file. The list is shipped at /usr/share/blueberry/flatpaks.list and
# also installed at firstboot.
```

- [ ] **Step 4: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest cat /usr/share/blueberry/flatpaks.list | wc -l`
Expected: ≥ 28.

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/flatpak/ system_files/usr/share/blueberry/flatpaks.list build_files/40-flatpaks.sh
git commit -m "feat: flatpak list + flathub remote scaffolding"
```

### Task 5.2: Firstboot service (per-user one-shot)

**Files:**
- Create: `system_files/etc/systemd/user/blueberry-firstboot.service`
- Create: `system_files/usr/share/blueberry/firstboot/setup.sh`
- Modify: `build_files/10-services.sh`

- [ ] **Step 1: Write firstboot script**

```bash
#!/usr/bin/env bash
# Run once per user. Idempotent.
set -eu

marker="$HOME/.config/blueberry/firstboot.done"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")"

# Add Flathub remote for this user
flatpak remote-add --if-not-exists --user flathub /etc/flatpak/remotes.d/flathub.flatpakrepo

# Install flatpaks
while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    flatpak install --user --noninteractive --or-update flathub "$ref" || true
done < /usr/share/blueberry/flatpaks.list

# Symlink EasyEffects preset into the Flatpak sandbox config
ee_dir="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output"
mkdir -p "$ee_dir"
ln -sf /etc/blueberry/easyeffects/cab-fw.json "$ee_dir/cab-fw.json"

# Switch login shell to zsh
if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh "$USER" || true
fi

touch "$marker"
```

- [ ] **Step 2: Write the user systemd unit**

```ini
[Unit]
Description=Blueberry first-boot user setup
ConditionPathExists=!%h/.config/blueberry/firstboot.done

[Service]
Type=oneshot
ExecStart=/usr/share/blueberry/firstboot/setup.sh

[Install]
WantedBy=default.target
```

- [ ] **Step 3: Globally enable user service via preset**

Create `system_files/etc/systemd/user-preset/90-blueberry.preset`:
```
enable blueberry-firstboot.service
```

- [ ] **Step 4: chmod the script**

Append to `build_files/40-flatpaks.sh`:
```bash
chmod +x /usr/share/blueberry/firstboot/setup.sh
```

- [ ] **Step 5: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest test -x /usr/share/blueberry/firstboot/setup.sh && echo OK`
Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add system_files/etc/systemd/user/ system_files/etc/systemd/user-preset/ system_files/usr/share/blueberry/firstboot/ build_files/40-flatpaks.sh
git commit -m "feat: firstboot service for flatpaks, easyeffects, chsh"
```

---

## Phase 6 — `ujust` recipes

### Task 6.1: Install just recipes

**Files:**
- Create: `system_files/usr/share/ublue-os/just/60-blueberry.just`
- Modify: `build_files/50-ujust.sh`

- [ ] **Step 1: Write the recipes**

```just
# Update the system: rpm-ostree, flatpaks, distrobox, and homebrew (if present)
update:
    rpm-ostree update
    flatpak update --user --noninteractive
    -distrobox upgrade --all
    -[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && /home/linuxbrew/.linuxbrew/bin/brew upgrade

# Verify the running image's signature against the embedded cosign key
verify-image:
    #!/usr/bin/env bash
    set -eu
    img="$(rpm-ostree status --json | jq -r '.deployments[0]."container-image-reference"' | sed 's|^[^:]*://||')"
    cosign verify --key /etc/pki/containers/blueberry-cosign.pub "$img"

# Roll back to the previous deployment
rollback:
    rpm-ostree rollback
    @echo "Reboot to apply."

# Assemble the default Fedora distrobox
assemble-distrobox:
    distrobox assemble create --file /usr/share/blueberry/distrobox/distrobox.ini

# Toggle the Framework charge limit between 80% and 100%
toggle-charge-limit:
    #!/usr/bin/env bash
    set -eu
    f=/sys/class/power_supply/BAT1/charge_control_end_threshold
    cur="$(cat "$f")"
    if [ "$cur" = "80" ]; then
        echo 100 | sudo tee "$f"
    else
        echo 80 | sudo tee "$f"
    fi
```

- [ ] **Step 2: Wire `50-ujust.sh`**

```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Installing ujust recipes"
# Recipes are copied via system_files; no further action required.
# base-main already provides /usr/bin/ujust which sources /usr/share/ublue-os/just/*.just.
```

- [ ] **Step 3: Build and smoke-test recipe parsing**

Run: `just build && podman run --rm localhost/blueberry:latest just --justfile /usr/share/ublue-os/just/60-blueberry.just --list`
Expected: lists `update`, `verify-image`, `rollback`, `assemble-distrobox`, `toggle-charge-limit`.

- [ ] **Step 4: Commit**

```bash
git add system_files/usr/share/ublue-os/just/ build_files/50-ujust.sh
git commit -m "feat: ujust recipes (update, verify-image, rollback, charge-limit)"
```

### Task 6.2: Distrobox default assembly

**Files:**
- Create: `system_files/usr/share/blueberry/distrobox/distrobox.ini`

- [ ] **Step 1: Write the assembly file**

```ini
[fedora]
image=registry.fedoraproject.org/fedora-toolbox:44
init=false
nvidia=false
pull=true
root=false
replace=false
start_now=false
```

- [ ] **Step 2: Build and verify**

Run: `just build && podman run --rm localhost/blueberry:latest cat /usr/share/blueberry/distrobox/distrobox.ini | head -1`
Expected: `[fedora]`.

- [ ] **Step 3: Commit**

```bash
git add system_files/usr/share/blueberry/distrobox/
git commit -m "feat: default distrobox assembly (fedora-toolbox:44)"
```

---

## Phase 7 — Disk image build (functional VM testing)

### Task 7.1: Wire bootc-image-builder to new image name

**Files:**
- Modify: `disk_config/disk.toml` (and any sibling toml files)

- [ ] **Step 1: List disk_config files**

Run: `ls disk_config/`

- [ ] **Step 2: For each `*.toml`, replace the image reference**

In each file, find the `[[customizations.user]]` and any `image-ref` lines pointing at the old template image. Update to `ghcr.io/<owner>/blueberry:stable` (use the actual GHCR owner).

- [ ] **Step 3: Smoke-test qcow2 build (slow — 10–20 min)**

Run: `just build-qcow2 blueberry latest`
Expected: produces `output/qcow2/disk.qcow2` (or similar). If this errors with sudo prompts or missing kvm, document it but don't block — CI will exercise the same path.

- [ ] **Step 4: Boot the qcow2 in a VM**

Run: `just run-vm-qcow2 blueberry latest`
Expected: VM boots, greetd shows tuigreet, you can log in (use the user created by firstboot or the disk_config user) and reach a sway session.

- [ ] **Step 5: Commit toml changes**

```bash
git add disk_config/
git commit -m "feat: point disk_config at blueberry image"
```

### Task 7.2: CI publishes signed image to GHCR

**Files:**
- Modify: `.github/workflows/build.yml`

- [ ] **Step 1: Read current build.yml**

Confirm the workflow already calls `cosign sign` using `${{ secrets.SIGNING_SECRET }}`.

- [ ] **Step 2: If missing, add cosign sign step**

After the `podman push` step:
```yaml
      - name: Sign container image
        run: |
          echo "${{ secrets.SIGNING_SECRET }}" > cosign.key
          cosign sign --yes --key cosign.key ghcr.io/${{ github.repository_owner }}/blueberry@${{ steps.push.outputs.digest }}
          rm -f cosign.key
        env:
          COSIGN_PASSWORD: ""
```

- [ ] **Step 3: Push to a feature branch and watch CI**

```bash
git push -u origin HEAD
gh run watch
```
Expected: build green, image pushed to `ghcr.io/<owner>/blueberry:stable`, signature attached.

- [ ] **Step 4: Verify signature locally against the published image**

Run: `cosign verify --key cosign.pub ghcr.io/<owner>/blueberry:stable`
Expected: signature OK.

- [ ] **Step 5: Commit any workflow tweaks**

```bash
git add .github/workflows/build.yml
git commit -m "ci: cosign sign on push"
```

---

## Phase 8 — Documentation & cleanup

### Task 8.1: Rewrite `README.md` for Blueberry

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace template README with project README**

The new README should cover:
- What Blueberry is (one paragraph)
- Target hardware (Framework AMD AI 300)
- How to rebase from another bootc image: `sudo bootc switch ghcr.io/<owner>/blueberry:stable`
- Local dev: `just build`, `just build-qcow2`, `just run-vm-qcow2`
- `ujust` command list with one-liner descriptions
- Link to `docs/specs/2026-04-25-blueberry-design.md`
- License

(Engineer: write one paragraph per heading; do not copy the upstream template wholesale.)

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for blueberry"
```

### Task 8.2: Cleanup pass

**Files:**
- Modify: `build_files/99-cleanup.sh`

- [ ] **Step 1: Wire cleanup**

```bash
#!/usr/bin/env bash
set -ouex pipefail
. /ctx/lib.sh
log "Cleanup"

# Remove dnf/rpm metadata caches built during layering
rm -rf /var/lib/dnf /var/cache/dnf /var/cache/rpm-ostree
rm -rf /tmp/* /var/tmp/*

# Reset machine-id so each install gets a fresh one
:> /etc/machine-id

# bootc lint runs in the Containerfile; nothing else needed here.
```

- [ ] **Step 2: Build, confirm size dropped**

Run: `just build`
Expected: size smaller than the pre-cleanup build.

- [ ] **Step 3: Final commit**

```bash
git add build_files/99-cleanup.sh
git commit -m "feat: build cleanup pass"
```

### Task 8.3: End-to-end acceptance

- [ ] **Step 1: Build, push, install on a test VM**

```bash
just build
just build-qcow2
just run-vm-qcow2
```
In the VM, run through the acceptance checklist from the spec:
1. greetd login works
2. sway starts
3. waybar shows all modules
4. `ujust update` runs without error
5. `ujust verify-image` passes
6. flatpaks installed at firstboot
7. firewalld port 53317 open (`firewall-cmd --list-ports`)
8. usbguard active (`systemctl is-active usbguard`)
9. auditd active
10. `cosign verify` passes against the published image (run on host, not VM)

- [ ] **Step 2: Final tag**

When all 10 pass:
```bash
git tag -a v0.1.0 -m "blueberry v0.1.0 — initial release"
git push --tags
```

---

## Self-review notes

- **Spec coverage:** All sections of `2026-04-25-blueberry-design.md` are mapped: foundation (Phase 1), security (Phase 2), desktop (Phase 3), hardware (Phase 4), apps (Phase 5), ujust/branding (Phase 6 + 3.3 + 3.4), disk image (Phase 7), docs (Phase 8). The Local Test Loop section is exercised by Tasks 1.1 step 7, 7.1, and 8.3.
- **Out-of-scope items confirmed:** per-user dotfiles (kitty, nvim, zsh, sway keybinds, waybar style, mako, rofi theme, firefox, GPG, k9s, anki) — these belong to the chezmoi repo and are not tasks here.
- **Type/name consistency:** image name `blueberry` everywhere; `ghcr.io/<owner>/blueberry:stable` for both Containerfile reference (cosign policy) and disk_config/CI; `cosign.pub` filename consistent; user systemd unit named `blueberry-firstboot.service` everywhere.
- **Placeholder check:** The Plymouth logo and EasyEffects preset have explicit fallback instructions ("write a placeholder, TODO real asset"). All other steps contain actual code/commands.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-04-25-blueberry-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
