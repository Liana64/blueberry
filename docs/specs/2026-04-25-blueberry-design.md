# Blueberry — Design

- **Status:** Draft, awaiting user review
- **Date:** 2026-04-25
- **Author:** Liana64
- **Repo:** `github.com/Liana64/blueberry`
- **Image:** `ghcr.io/liana64/blueberry`

## Summary

Blueberry is an opinionated, atomic, image-based Linux distribution targeted
at the Framework AMD AI 300 series laptop. It is a derivative of
`ghcr.io/ublue-os/base-main` (Fedora 44 atomic) layered with Sway, a
hand-curated security stack, Framework hardware support, and a Bazzite-style
`ujust` command surface — minus the gaming focus. The image is built from
the `ublue-os/image-template` (Containerfile + `bootc`), signed with cosign,
and shipped both as an OCI image and as a bootable ISO/qcow2/raw produced by
`bootc-image-builder`.

It replaces a pre-existing NixOS flake (`~/.dotfiles`) on the same hardware.
Per-user CLI configuration (zsh, nvim, k9s, atuin, starship, git identity,
gpg, ssh, shell aliases) is migrated to a separate chezmoi repo, out of
scope for this spec.

## Goals

1. A reproducible, signed, atomic Linux image suitable for daily use as a
   single-user developer workstation.
2. Strong system-level security posture leveraging Fedora SELinux,
   composefs read-only `/usr`, signed-image verification, kernel hardening,
   USBGuard, Linux audit, faillock, and mainline Secure Boot.
3. Functional parity with the user's current NixOS install for Sway,
   Framework hardware (battery limits, fingerprint, YubiKey, CalDigit TS4
   dock, EasyEffects DSP), Flatpak app inventory, and CLI tooling.
4. A bootable installer ISO that yields a working Blueberry box with LUKS
   in one step (no Fedora-then-rebase intermediate).
5. A `ujust` command surface for lifecycle, setup, hardware, and diagnostics
   that mirrors Bazzite's UX without inheriting its gaming-specific bits.

## Non-goals

- Multi-host support beyond Framework AMD AI 300 (DMI condition included
  for future broadening but not exercised).
- Migration of the `oob` (Raspberry Pi) and `small` (macOS) hosts — they
  remain on their existing NixOS / home-manager setups.
- Per-user dotfile content (chezmoi territory).
- Gaming-related bits (no Steam, no GameMode, no overlay).
- Hardened-malloc, Trivalent, bubblejail (deliberately rejected).
- Auto-updates (manual `ujust update` only).
- DNS-over-TLS / systemd-resolved (relying on upstream secure DNS).

## Architecture

### Repository layout

The repo follows the `ublue-os/image-template` (Containerfile-based, not
the older bluebuild YAML recipe DSL):

```
~/blueberry/
├── Containerfile
├── build_files/
│   ├── build.sh
│   ├── 10-repos.sh
│   ├── 20-packages.sh
│   ├── 30-services.sh
│   ├── 40-flatpaks.sh
│   ├── 50-hardening.sh
│   ├── 60-branding.sh
│   ├── 70-ujust.sh
│   └── 99-cleanup.sh
├── system_files/
│   ├── etc/
│   │   ├── sway/config
│   │   ├── xdg/{waybar,mako,rofi}/
│   │   ├── kitty/kitty.conf
│   │   ├── usbguard/{usbguard-daemon.conf,rules.d/}
│   │   ├── sysctl.d/99-blueberry-hardening.conf
│   │   ├── modprobe.d/99-blueberry-blacklist.conf
│   │   ├── audit/rules.d/99-blueberry.rules
│   │   ├── chrony.conf
│   │   ├── faillock.conf
│   │   ├── greetd/config.toml
│   │   ├── easyeffects/output/cab-fw.json
│   │   ├── firefox/policies/policies.json
│   │   ├── flatpak/overrides/
│   │   ├── pam.d/
│   │   ├── NetworkManager/dispatcher.d/90-wg-autoconnect
│   │   ├── udev/rules.d/
│   │   └── systemd/system/
│   │       ├── blueberry-firstboot.service
│   │       └── inhibit-sleep-when-docked.service
│   └── usr/
│       ├── share/
│       │   ├── backgrounds/blueberry/flower.png
│       │   ├── plymouth/themes/blueberry/
│       │   └── ublue-os/just/{60-blueberry,70-framework}.just
│       └── libexec/blueberry/
│           ├── motd-render
│           ├── audit-summarize
│           ├── sway-screenshot-all
│           ├── sway-screenshot-area
│           └── firstboot-bootstrap
├── disk_config/
│   ├── disk.toml
│   └── iso-sway.toml
├── docs/
│   ├── specs/2026-04-25-blueberry-design.md
│   ├── install.md
│   └── MIGRATION.md
├── .github/workflows/
│   ├── build.yml
│   └── build-disk.yml
├── Justfile
├── artifacthub-repo.yml
├── cosign.pub
└── README.md
```

### Build pipeline

- **Containerfile:** `FROM ghcr.io/ublue-os/base-main:latest` → COPY
  `build_files/` from a scratch context → RUN `build.sh` (which sources
  the numbered fragments) → COPY `system_files/` into `/` → `bootc
  container lint`.
- **build.sh** sources `[0-9][0-9]-*.sh` in numeric order; each fragment
  is idempotent and assertion-driven (e.g., 20-packages asserts kernel
  major ≥ 7 after install).
- **GitHub Actions:**
  - `.github/workflows/build.yml` — push, daily cron, manual dispatch.
    Builds OCI image, signs with cosign (`SIGNING_SECRET`), pushes to GHCR
    with tags `latest` and `YYYYMMDD`. Removes any prior dated tag older
    than 30 days.
  - `.github/workflows/build-disk.yml` — gated on `build.yml` success.
    Builds ISO + qcow2 + raw via `bootc-image-builder` using
    `disk_config/iso-sway.toml`. Publishes to GH releases on dated tags;
    optionally to S3 if `S3_*` secrets are set.
- **Cosign:** `cosign.pub` committed at repo root; deployed to
  `/etc/pki/containers/blueberry-cosign.pub` on the host. Private key is
  GH Actions secret `SIGNING_SECRET`.

### Local test loop

Two artifacts, two purposes:

- **OCI image** (`just build` → local `podman` registry, or `podman pull
  ghcr.io/liana64/blueberry:latest` after CI). Useful for filesystem
  inspection: `podman run -it ghcr.io/liana64/blueberry:latest
  /bin/bash` to verify packages installed, configs at expected paths,
  `ujust` recipes present, audit rules deployed. systemd / sway /
  PipeWire / udev / USBGuard will **not** function in a container —
  they require PID 1 systemd and host kernel access.
- **Disk image** (`just build-qcow2 && just run-vm-qcow2`, or
  `just spawn-vm` for `systemd-vmspawn`). Boots the image as a VM with
  full systemd, services, audit, sway. This is the canonical way to
  verify behavior before pushing. The bootable ISO published by
  `build-disk.yml` on dated tags is the same artifact end users `dd`
  to USB.

Typical iteration: edit → `just build` → `podman run` for static
checks → `just build-qcow2 && just run-vm-qcow2` for runtime checks →
commit + push → CI signs and publishes.

### Base image

- `ghcr.io/ublue-os/base-main:latest` (Fedora 44 atomic, ublue-os
  customizations: ujust framework, `ublue-update` machinery, MOTD
  plumbing). Pinned to `latest` rebuilt nightly via the daily cron;
  immediate rollback path is `bootc rollback`.

## Section 1 — Repo & build pipeline

Covered above under Architecture.

CI guards (in `99-cleanup.sh` or as a CI step):

- Assert `KERNEL_MAJOR ≥ 7` (read from `/lib/modules/*/modules.dep` path
  during build).
- `bootc container lint` (template default).
- `shfmt` and `shellcheck` on `build_files/*.sh`.
- `just check` on the Justfile.

## Section 2 — Security baseline

### Inherited from base

- SELinux enforcing.
- composefs read-only `/usr`.
- Cosign-signed image, verified by rpm-ostree on update via
  `/etc/containers/policy.json` referencing the embedded
  `/etc/pki/containers/blueberry-cosign.pub`.
- Fedora-signed shim/GRUB/kernel chain (Secure Boot via Fedora keys, not
  user-managed sbctl). Image cosign signature is the user-controlled root
  of trust.
- bootc-native deploy and rollback.

### Kernel cmdline (`/usr/lib/bootc/kargs.d/blueberry-hardening.toml`)

```
lockdown=confidentiality
module.sig_enforce=1
init_on_alloc=1
init_on_free=1
page_alloc.shuffle=1
randomize_kstack_offset=on
vsyscall=none
mitigations=auto,nosmt
```

### Sysctl (`/etc/sysctl.d/99-blueberry-hardening.conf`)

```
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.kexec_load_disabled = 1
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
```

### Module blacklist (`/etc/modprobe.d/99-blueberry-blacklist.conf`)

`firewire-core`, `firewire-ohci`, `firewire-sbp2`, `udf`, `cramfs`,
`freevxfs`, `jffs2`, `hfs`, `hfsplus`, `squashfs`, `cifs`, `nfs`,
`nfsv3`, `nfsv4`, `ksmbd`, `gfs2`, `dccp`, `sctp`, `rds`, `tipc`.

### USBGuard

- Daemon config: `presentControllerPolicy = apply-policy`,
  `IPCAllowedGroups = wheel`, `AuditBackend = LinuxAudit`,
  `RuleFile = /etc/usbguard/rules.conf`.
- D-Bus interface enabled (`usbguard-dbus.service`) so the waybar
  module can talk to it.
- Static admin rules in `/etc/usbguard/rules.d/` (empty by default).
- `rules.conf` populated post-install via
  `ujust setup-usbguard` (wraps `usbguard generate-policy`).
- Companion services: `udisks2`, `gvfs`, `devmon` enabled for USB
  automount once a device is authorized.

### Faillock

- 5 attempts, 600s lockout.
- Applied to `system-auth`, `password-auth`, `sudo`, `swaylock`, greetd
  PAM stack.

### Firewalld

- Default zone: `block`.
- Allowlist: 53317/tcp, 53317/udp (localsend).
- Syncthing ports (22000/tcp, 21027/udp) opened on demand by
  `ujust setup-syncthing`.

### chrony (`/etc/chrony.conf`)

- NTS only.
- Servers: `time.nist.gov`, `time.cloudflare.com`, `nts.netnod.se`.
- `makestep 0.1 3`, `rtcsync`.

### Locale & timezone

- `/etc/locale.conf`: `LANG=en_US.UTF-8` plus the LC_* override set
  matching the NixOS install.
- `/etc/localtime` → `America/Chicago`.

### PAM stack

- `pam_u2f` with `cue=true` on sudo, login, swaylock.
- `pam_faillock` on local logins.
- `pam_gnome_keyring` for greetd → keyring auto-unlock.
- `pam_fprintd` opt-in (user enrolls via `ujust enroll-fingerprint`).
- GnuPG agent with SSH support: `~/.gnupg/gpg-agent.conf` (chezmoi)
  + system gpg-agent socket activation.

### Disabled services

- `xdg-desktop-portal-wlr.service` (no screencast surface;
  `ujust enable-screencast` to flip).
- `bluetooth.service` disabled at boot, plus `bluetoothctl power off`
  via session start (matches NixOS `powerOnBoot = false`); waybar
  toggle starts the service and powers the radio on.
- `avahi-daemon.service`, `cups-browsed.service`, `geoclue.service`,
  `abrt-*.service`, `packagekit.service`.
- No sshd; not installed.

### Auto-update

- **Disabled.** No rpm-ostree timer, no flatpak timer.
- `ujust update` is canonical: runs `rpm-ostree upgrade` (or `bootc
  upgrade` once stable), `flatpak update -y`, `distrobox upgrade --all`,
  `brew update && brew upgrade`. Sets `/run/blueberry/deploy-in-progress`
  marker so the audit summarizer skips events during the window.
- MOTD nags (purple) when a deployment is staged but not applied.

### WireGuard auto-connect

- NetworkManager dispatcher script at
  `/etc/NetworkManager/dispatcher.d/90-wg-autoconnect` (verbatim port of
  the NixOS `modules/linux/wireguard.nix` logic): listens for
  `connectivity-change`; brings `wg0` up unless on ethernet or a known
  SSID.
- `/etc/NetworkManager/conf.d/10-blueberry.conf` sets
  `keyfile.unmanaged-devices=interface-name:wg0` so NM does not try to
  manage the interface, and ensures connectivity check is enabled
  (`connectivity.uri=https://nmcheck.gnome.org/check_network_status.txt`).
- Config files at `/etc/blueberry/wireguard/{wg0.conf,trusted-networks}`
  (mode 0600, root-owned). Populated post-install by
  `ujust setup-wireguard`.

### Linux audit

Strict 0-baseline anomaly log.

`/etc/audit/rules.d/99-blueberry.rules`:

```
-b 8192
-f 1

# Identity & authorization
-w /etc/passwd        -p wa -k identity
-w /etc/shadow        -p wa -k identity
-w /etc/group         -p wa -k identity
-w /etc/gshadow       -p wa -k identity
-w /etc/sudoers       -p wa -k identity
-w /etc/sudoers.d/    -p wa -k identity
-w /etc/security/     -p wa -k identity

# PAM / authentication config
-w /etc/pam.d/        -p wa -k auth
-w /etc/login.defs    -p wa -k auth

# SSH (in case sshd is ever turned on)
-w /etc/ssh/sshd_config -p wa -k sshd

# SELinux policy + booleans (config only; image-tree changes excluded)
-w /etc/selinux/      -p wa -k MAC-policy

# USBGuard config (rules.conf excluded — daemon writes it on user
# authorizations; that signal is captured via USBGuard's AuditBackend)
-w /etc/usbguard/usbguard-daemon.conf  -p wa -k usbguard-config
-w /etc/usbguard/rules.d/              -p wa -k usbguard-config
-w /etc/usbguard/IPCAccessControl.d/   -p wa -k usbguard-config

# Systemd unit injection (image deploy path is /usr/lib; only catches
# local/unauthorized changes)
-w /etc/systemd/system/             -p wa -k systemd
-w /etc/systemd/user/               -p wa -k systemd
-w /usr/local/lib/systemd/system/   -p wa -k systemd

# Network configuration (system-connections excluded — saved Wi-Fi is
# normal user activity)
-w /etc/NetworkManager/NetworkManager.conf -p wa -k network
-w /etc/NetworkManager/conf.d/             -p wa -k network
-w /etc/NetworkManager/dispatcher.d/       -p wa -k network
-w /etc/hosts            -p wa -k network
-w /etc/firewalld/       -p wa -k network

# Time (auid filter excludes chrony's continuous adjtimex)
-w /etc/localtime         -p wa -k time-change
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime \
   -F auid>=1000 -F auid!=unset -k time-change

# Kernel modules (auid filter excludes udev's automatic loads)
-a always,exit -F arch=b64 -S init_module -S finit_module -S delete_module \
   -F auid>=1000 -F auid!=unset -k modules

# Cron / timers
-w /etc/cron.allow   -p wa -k cron
-w /etc/cron.deny    -p wa -k cron
-w /etc/crontab      -p wa -k cron
-w /etc/cron.d/      -p wa -k cron

# Image manifest
-w /etc/rpm-ostreed.conf  -p wa -k rpm-ostree

# Blueberry-managed config (WireGuard + trusted SSIDs)
-w /etc/blueberry/    -p wa -k blueberry-config

# Drop successful auth events; failures still fire
-a always,exclude -F msgtype=USER_LOGIN  -F res=success
-a always,exclude -F msgtype=USER_AUTH   -F res=success
-a always,exclude -F msgtype=USER_ACCT   -F res=success
-a always,exclude -F msgtype=USER_START  -F res=success
-a always,exclude -F msgtype=USER_END    -F res=success
-a always,exclude -F msgtype=CRED_ACQ    -F res=success
-a always,exclude -F msgtype=CRED_DISP   -F res=success
-a always,exclude -F msgtype=CRED_REFR   -F res=success
-a always,exclude -F msgtype=USER_CMD    -F res=success
-a always,exclude -F msgtype=SERVICE_START
-a always,exclude -F msgtype=SERVICE_STOP
-a always,exclude -F msgtype=CRYPTO_SESSION  -F res=success
-a always,exclude -F msgtype=CRYPTO_KEY_USER -F res=success

-e 2
```

`auditd` config: `disk_full_action = SUSPEND`, `max_log_file = 32`,
`num_logs = 6`. MOTD audit summarizer at
`/usr/libexec/blueberry/audit-summarize` filters events whose timestamp
falls within an active deploy window (correlated against
`rpm-ostreed.service` activity in journald ± 60s).

## Section 3 — Desktop layer

### Compositor

Sway, system-wide config at `/etc/sway/config`. Direct port of the
NixOS `home/linux/sway.nix` into a static config (modifier `Mod1`,
workspace bindings q/w/e/a/s/d/z/x/c, autotiling, swayidle/swaylock
launch from sway startup, lid + dock bindswitch, output config for
`eDP-1` 2880x1920@120Hz and `DP-5` 3440x1440@144Hz, polkit-gnome auth
agent, kitty session startup, modes for power/lock).

User-level overrides via `include ~/.config/sway/config.d/*` at the
end of the system config.

### Bar / notifications / launcher

- Waybar at `/etc/xdg/waybar/` ports `home/linux/waybar.nix`. Modules:
  - left: `custom/launcher` (icon → `rofi -show drun`),
    `sway/workspaces` (persistent q/w/e/a/s/d/z/x/c), `sway/mode`.
  - center: `clock`.
  - right: `custom/yubikey` (touch indicator, JSON from
    `/usr/libexec/blueberry/waybar-yubikey`), `custom/usbguard`
    (`/usr/libexec/blueberry/waybar-usbguard`, click=allow,
    right-click=reject), `custom/syncthing` (pgrep-based status with
    onclick → `firefox https://127.0.0.1:8384/`), `custom/vpn`
    (presence of `/proc/sys/net/ipv4/conf/wg0`), `custom/rpm-ostree`
    (purple dot when staged, red when reboot pending — replaces nothing
    in NixOS, new), `network`, `battery` (warning=35, critical=15),
    `bluetooth` (click → `blueman-manager`, right-click →
    `rfkill toggle bluetooth`), `pulseaudio` (click → `pavucontrol`),
    `tray`.
  - Style: groove palette (darker bg, white fg, red on
    disconnected/critical, orange on warning, green on charging /
    bluetooth-connected / vpn-connected, tan on ethernet /
    bluetooth-on).
- Mako at `/etc/xdg/mako/`, groove palette, default-timeout=3000,
  border-radius=5, font "JetBrainsMono Nerd Font 10".
- Rofi at `/etc/xdg/rofi/`, `rofi -show drun` is the menu, theme ported
  from NixOS `home/linux/rofi.nix` (groove palette, JetBrains Mono Nerd
  Font 12, 360px width, vertical listview). Vicinae not installed.

### Lock / idle

- swaylock with `flower.png` from `/usr/share/backgrounds/blueberry/`,
  indicator-radius 80, daemonize.
- swayidle: 300s lock, 600s display off, before-sleep lock.

### Terminal

Kitty at `/etc/xdg/kitty/kitty.conf`. Direct port of NixOS
`home/common/kitty.nix`: Dracula palette, 7-tab `startup.session`
(home, dev, ai, mon, ctl, rmt, perf), full keybind set, beam cursor,
200000 scrollback.

Font: **JetBrainsMono Nerd Font** (DanQing fallback — DanQing not
sourced).

### Greeter

greetd + tuigreet. Default session = sway. PAM stack: u2f (cue),
gnome-keyring unlock, faillock, fingerprint opt-in.

### Theme

- GTK 3/4: `adw-gtk3-dark`.
- Icons: `papirus-icon-theme-dark`.
- Cursor: `bibata-cursor-theme` (Bibata-Modern-Classic, 16px).
- Wallpaper: `flower.png` baked at
  `/usr/share/backgrounds/blueberry/flower.png`. Launched by swaybg
  in sway startup.
- dconf defaults via `gschema-overrides` (file-chooser sort/show-hidden
  settings, `color-scheme = prefer-dark`).

### Fonts

`google-noto-fonts`, `google-noto-emoji-fonts`,
`jetbrains-mono-nerd-fonts` (or `jetbrains-mono-fonts` + manual
symbols), `cabin-fonts` (Cantarell). Matches NixOS
`modules/linux/fonts.nix` exactly.

### Portals & polkit

- `xdg-desktop-portal-gtk` enabled (file picker).
- `xdg-desktop-portal-wlr` **disabled** at boot.
- `polkit-gnome-authentication-agent-1` started by sway's `startup`.

### Environment defaults (`/etc/environment`)

```
EDITOR=nvim
BROWSER=firefox
TERM=xterm-256color
ELECTRON_OZONE_PLATFORM_HINT=auto
QT_QPA_PLATFORM=wayland
MOZ_ENABLE_WAYLAND=1
SDL_VIDEODRIVER=wayland
GDK_SCALE=1
GDK_DPI_SCALE=1
QT_SCALE_FACTOR=1
QT_AUTO_SCREEN_SCALE_FACTOR=0
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
_JAVA_AWT_WM_NONREPARENTING=1
```

(plus `XDG_SESSION_TYPE`, `DESKTOP_SESSION`, `XDG_CURRENT_DESKTOP` set
by greetd at session start)

## Section 4 — Hardware (Framework AMD AI 300)

| Capability | Implementation |
|---|---|
| Kernel | Stock Fedora ≥ 7.0; build asserts |
| `framework_laptop` kmod | Mainline (kernel ≥ 6.10) |
| Firmware updates | `fwupd` via `ujust framework-firmware-update` |
| Battery charge limit | Direct sysfs: `/sys/class/power_supply/BAT1/charge_control_end_threshold`; `ujust framework-charge-limit` writes via pkexec; sticky via systemd unit re-applying on resume |
| Fingerprint | `fprintd`; `ujust enroll-fingerprint`; opt-in PAM line |
| YubiKey | `pcscd` enabled; `pam_u2f cue=true`; `ujust enroll-yubikey` |
| YubiKey touch indicator | `yubikey-touch-detector` user service; waybar module |
| Bluetooth | `bluetooth.service` masked at boot; `bluetoothctl power off` at session start; waybar toggle (`ujust toggle-bluetooth`) |
| Audio | PipeWire + WirePlumber + `pipewire-pulseaudio` + `pipewire-jack-audio-connection-kit`; auto-switch default sink to BT/dock per `wireplumber.settings.default-nodes.auto-switch = true` (drop-in at `/etc/wireplumber/wireplumber.conf.d/51-default-sink-auto-switch.conf`) |
| Speakers DSP | `framework-dsp` profile vendored from `cab404/framework-dsp` (Gracefu's Edits) baked into the image at `/etc/blueberry/easyeffects/cab-fw.json`; the user-systemd `blueberry-firstboot-user.service` symlinks it into `~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output/cab-fw.json` (the EasyEffects Flatpak's only writable preset path); `ujust framework-dsp-on/off` toggles by stamping a marker file the user service consumes |
| Power | `power-profiles-daemon` enabled; TLP not installed; `upower` with `PercentageLow=15` and `PercentageCritical=5` (matches NixOS) |
| Thermal sensors | `lm_sensors`; `iio-sensor-proxy` not installed (no auto-rotation, no light sensor) |
| Thunderbolt / CalDigit TS4 | `bolt` enabled; udev rule + `inhibit-sleep-when-docked.service` ported verbatim from NixOS to `/etc/systemd/system/` and `/etc/udev/rules.d/`; `ujust dock-status` |
| Lid behavior | `HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=suspend`, `HandleLidSwitchDocked=ignore` |
| Suspend lock | systemd unit running `swaylock -f` before-sleep |
| SSD | `fstrim.timer`, `smartd` |
| Printing | CUPS on, `cups-browsed` off |
| Wireshark | `wireshark-cli` ships `dumpcap` with `cap_net_raw,cap_net_admin+eip`; `wireshark` group; user added at install time |

## Section 5 — Apps & dev tooling

### Default Flatpaks (installed by firstboot service)

Verified flathub (auto-installed):

```
org.signal.Signal
org.gnome.Calculator
org.gnome.Loupe
org.gnome.Maps
org.gnome.TextEditor
org.gnome.Snapshot
org.gnome.Characters
org.gnome.Calendar
org.gnome.Mahjongg
com.github.finefindus.eyedropper
dev.bragefuglseth.Fretboard
org.mozilla.Thunderbird
org.mozilla.firefox
org.gimp.GIMP
org.libreoffice.LibreOffice
org.localsend.localsend_app
org.pulseaudio.pavucontrol
com.moonlight_stream.Moonlight
com.bitwarden.desktop
com.rustdesk.RustDesk
com.github.tchx84.Flatseal
dev.vencord.Vesktop
md.obsidian.Obsidian
io.github.ungoogled_software.ungoogled_chromium
com.jgraph.drawio.desktop
com.github.wwmm.easyeffects
```

Unverified flathub (auto-installed):

```
org.videolan.VLC
me.proton.Mail
us.zoom.Zoom
ch.protonmail.protonmail-bridge
```

Per-Flatpak overrides (`/etc/flatpak/overrides/`):

- `org.mozilla.firefox`: `--filesystem=/etc/firefox:ro`
- `com.github.wwmm.easyeffects`: `--filesystem=/etc/easyeffects:ro`
- `com.jgraph.drawio.desktop`: extra arg
  `--enable-gpu-rasterization` (matches NixOS drawio wrapper)
- `ch.protonmail.protonmail-bridge`: starts as user service via
  `xdg autostart`, replaces NixOS `services.protonmail-bridge`
- Wayland default for all (`--socket=wayland`)

### Firefox `policies.json` (`/etc/firefox/policies/policies.json`)

System-wide. Honored by the Flatpak via the override. Settings ported
from NixOS `home/linux/firefox.nix`:

- All telemetry off (full set).
- `DisableFirefoxStudies`, `DisablePocket`, `DisableAccounts`,
  `DontCheckDefaultBrowser`, `OverrideFirstRunPage = ""`,
  `OverridePostUpdatePage = ""`.
- `EnableTrackingProtection`, `HttpsOnlyMode = enabled`.
- `Homepage = https://labs.lianas.org`.
- `SearchEngines.Default = "Kagi"`; engines: Kagi, GitHub, Flathub,
  Kubesearch, Nixpkgs, Nix Options, OpenSecrets; `Remove = ["Bing"]`.
- GPU/VAAPI flags via `Preferences`: `gfx.webrender.all`,
  `media.ffmpeg.vaapi.enabled`, `widget.dmabuf.force-enabled`.
- `Extensions.Install`: Sidebery, ublock-origin.

### Default file associations

System-wide MIME defaults match NixOS `home/linux/firefox.nix`
`xdg.mimeApps`: HTML/HTTP/HTTPS/PDF → Firefox; terminal scheme →
Kitty; text/plain → GNOME Text Editor; images → GNOME Loupe.

### CLI tooling — RPM-layered (host)

```
git, git-delta, bat, eza, ripgrep, fd-find, fzf, zoxide, jq, yq,
btop, just, lazygit, helm, kubectl, ansible, pre-commit, tldr,
ffmpeg (via RPM Fusion swap from ffmpeg-free), ImageMagick,
ShellCheck, gptfdisk, traceroute, bind-utils (dig), bc, cosign,
dmidecode, ethtool, hdparm, nvme-cli, sbctl, smartmontools,
sysstat, tcpdump, inotify-tools, lm_sensors, libnotify, unzip,
wget, android-tools, wireshark-cli, wireshark, usbutils, pciutils,
udisks2, gvfs, seahorse, gnupg2, yubikey-manager, yubikey-personalization,
yubikey-touch-detector, blueman, brightnessctl, playerctl,
polkit-gnome, pipewire-pulseaudio, pipewire-jack-audio-connection-kit,
wireplumber, sway, swaylock, swayidle, swaybg, waybar, mako,
rofi-wayland, kitty, autotiling, grim, slurp, wl-clipboard, libsecret,
gnome-keyring, fprintd, greetd, tuigreet, papirus-icon-theme-dark,
adw-gtk3, bibata-cursor-theme, chrony, usbguard, audit, pam-faillock,
wireguard-tools, firewalld, fwupd, bolt, distrobox, podman,
podman-docker, toolbox, fastfetch, htop, perf, zsh, util-linux-user
(for `chsh`)
```

### CLI tooling — Homebrew (user-level, `/home/linuxbrew`)

`brew bundle` from a baked Brewfile, run by
`blueberry-firstboot-user.service` on first login.

```
talosctl
talhelper
cilium-cli
fluxcd
kubeconform
bitwarden-cli
age
sops
ripgrep-all
go-task
watchexec
hexyl
dust
duf
procs
yazi
nixd
marksman
yaml-language-server
lua-language-server
rust-analyzer
```

### Default distrobox container (`dev-fedora`)

- Image: `registry.fedoraproject.org/fedora-toolbox:latest`.
- Created by firstboot service.
- `ujust toolbox-dev` recreates.
- Common dev tools (gcc, make, python, etc.) installed inside via
  firstboot script.

### Cider 2 (no flathub presence, no COPR)

Installed via `ujust install-cider`: creates `apps-cider` distrobox,
installs upstream Cider RPM inside, runs `distrobox-export --app
cider`. Host stays clean; Cider runs sandboxed in the container.

### RPM Fusion

`rpmfusion-free-release` and `rpmfusion-nonfree-release` enabled in
`10-repos.sh`. `ffmpeg-free` swapped for `ffmpeg` in `20-packages.sh`.

## Section 6 — `ujust` commands, branding, MOTD, first-boot

### `ujust` commands

Shipped at `/usr/share/ublue-os/just/60-blueberry.just` and
`70-framework.just`.

**Lifecycle**

- `ujust update`
- `ujust rollback` (wraps `bootc rollback`)
- `ujust changelog` (diffs deployed image labels)
- `ujust verify-image` (`cosign verify` against booted deployment)
- `ujust factory-reset` (wraps `rpm-ostree reset`)

**First-time setup**

- `ujust setup-bootstrap` (re-runs the firstboot flow interactively)
- `ujust setup-wireguard` (interactive paste of wg0.conf + trusted
  SSIDs; writes `/etc/blueberry/wireguard/`)
- `ujust setup-syncthing` (enables `syncthing.service` user unit;
  opens firewall ports)
- `ujust setup-usbguard` (wraps `usbguard generate-policy`)
- `ujust enroll-yubikey`
- `ujust enroll-fingerprint`

**Framework-specific**

- `ujust framework-charge-limit` (interactive 60–100, sysfs write
  via pkexec, sticky on resume)
- `ujust framework-firmware-update`
- `ujust framework-dsp-on` / `ujust framework-dsp-off`
- `ujust dock-status`

**Toggles & extras**

- `ujust toggle-bluetooth`
- `ujust enable-screencast` / `ujust disable-screencast`
- `ujust toggle-devmode` (gates `rpm-ostree install`; off by default)
- `ujust install-cider`
- `ujust install-extras` (interactive checkbox menu)
- `ujust install-codecs` (no-op stub if RPM Fusion default kept)

**Diagnostics**

- `ujust audit-summary`
- `ujust fix-flatpak-permissions`
- `ujust motd` (re-renders + displays)

### Branding

- **OCI labels:** `org.opencontainers.image.title=Blueberry`,
  `…description="Opinionated Sway atomic Fedora for Framework AMD AI
  300"`, `…vendor=Liana64`, `…licenses=MIT`.
- **`/etc/os-release`:** `NAME="Blueberry"`, `PRETTY_NAME="Blueberry
  (Sway atomic, Fedora 44)"`, `ID_LIKE=fedora`, `LOGO=blueberry`,
  `VARIANT="Sway"`, `VARIANT_ID=blueberry`,
  `DOCUMENTATION_URL=https://github.com/Liana64/blueberry`.
- **Plymouth:** custom theme `blueberry`, derived from `details`
  (lightweight). Accent `#d3869b` (groove pink). Boot logo: rendered
  at build time via ImageMagick from a JetBrainsMono "blueberry"
  wordmark; PNG at
  `/usr/share/plymouth/themes/blueberry/logo.png`.
  `blueberry.plymouth` and `blueberry.script` define the theme. Set
  default via `plymouth-set-default-theme blueberry -R` in
  `60-branding.sh`.
- **Bootloader entry title:** "Blueberry Linux".
- **`/etc/issue`:** purple ASCII "blueberry" wordmark.
- **tuigreet greeting:** purple accent, "blueberry" header.

### MOTD

Bazzite-style purple text. Per-session, single-display.

- `/etc/profile.d/blueberry-motd.sh` checks for marker
  `/run/user/$UID/.blueberry-motd-seen.$XDG_SESSION_ID`. Absent →
  display + create marker. Present → exit silent.
- `blueberry-motd.service` (user unit, `WantedBy=graphical-session
  .target`, `Type=oneshot`) renders MOTD content into
  `/run/user/$UID/blueberry-motd.cache`.
  `/etc/profile.d/blueberry-motd.sh` cats the cache.
- `ujust motd` re-renders + redisplays.
- Sections rendered: hostname/version line, image identity + cosign
  verification status, "update staged" warning if applicable, audit
  anomalies (last 24h, **omitted entirely if zero events**), state
  toggles (devmode/bluetooth/screencast/wireguard), tip line.
- Audit anomaly block is gated on the audit summarizer (Section 2)
  which excludes events during deploy windows.

### First-boot UX

- `/etc/systemd/system/blueberry-firstboot.service`:
  - `Type=oneshot`, `After=network-online.target`,
    `ConditionPathExists=!/var/lib/blueberry/firstboot.stamp`.
  - Adds flathub remote.
  - Installs all default Flatpaks.
  - Applies Flatpak overrides.
  - Creates `dev-fedora` distrobox (root creates the container; user
    enters it later).
  - Adds `liana` user to: `wheel`, `wireshark`, `kvm`, `dialout`,
    `input`.
  - Sets the user's login shell to `/usr/bin/zsh` via `chsh` (matches
    NixOS `users.users.liana.shell = pkgs.zsh`).
  - Touches stamp file.

- `/etc/systemd/user/blueberry-firstboot-user.service`:
  - `Type=oneshot`, `WantedBy=default.target`,
    `ConditionPathExists=!~/.local/state/blueberry/firstboot-user
    .stamp`.
  - Runs `brew bundle` against
    `/usr/share/blueberry/Brewfile`.
  - Sets up user systemd units: `gpg-agent.service` (with SSH
    support), `yubikey-touch-detector.service`,
    `syncthing.service` (disabled until `ujust setup-syncthing`).
  - Pops a kitty window with the **first-boot welcome MOTD** that
    walks the user through the recommended `ujust setup-*` recipes.
  - Touches stamp file.

## Section 7 — chezmoi handoff, install, secrets

### chezmoi handoff (out-of-scope summary)

When migrating from `~/.dotfiles` (NixOS), these move into a
separate chezmoi repo:

- `home/common/`: zsh, starship, atuin, k9s, nvim (full config +
  plugins), git config (user identity, signing, delta), kitty user
  overrides if any.
- `home/linux/`: aliases, gpg user config, claude config equivalent.
- Per-Flatpak user configs: Firefox `userChrome.css` for Sidebery,
  Bitwarden GUI prefs, Vesktop settings if customized.
- Personal secrets (gpg keys, ssh, B2) — restored from YubiKey/backup,
  not in chezmoi or any git repo.

What stays out of chezmoi (image owns it): sway, waybar, mako, rofi,
swaylock, swayidle, kitty global config, GTK theme, fonts, Flatpak
list + overrides, Firefox `policies.json`, all system services. The
`docs/MIGRATION.md` document covers this.

### Secrets

Nothing secret in the image or git. Storage:

| Secret | Location | Loaded |
|---|---|---|
| Cosign signing key | GH Actions secret `SIGNING_SECRET` | Build only |
| Cosign verification key | `/etc/pki/containers/blueberry-cosign.pub` (image) | bootc/rpm-ostree on update |
| WireGuard config | `/etc/blueberry/wireguard/wg0.conf` (0600 root:root) | `ujust setup-wireguard` post-install |
| WireGuard trusted SSIDs | `/etc/blueberry/wireguard/trusted-networks` (0600 root:root) | Same |
| YubiKey U2F mappings | `~/.config/Yubico/u2f_keys` (0600 user:user) | `ujust enroll-yubikey` |
| GPG keys | `~/.gnupg/` (on YubiKey) | Standard |
| ssh keys | YubiKey via gpg-agent SSH bridge | Standard |
| Bitwarden master password | bitwarden-cli session | Per-shell |
| Backblaze B2 keys | `~/.config/b2/account_info` | Standard |

`/etc/blueberry/`: 0700 directory, files 0600. Readers: wg-quick,
NetworkManager dispatcher, ujust scripts via pkexec.

### Install procedure

Documented in `docs/install.md`.

1. Download `blueberry-YYYYMMDD.iso` from the GH release. Verify
   checksum and cosign signature.
2. `dd` to USB.
3. Boot installer. Pick disk, set hostname, set user password,
   **enable LUKS** at the disk-encryption prompt.
4. Reboot. `blueberry-firstboot.service` runs (Flatpaks, distrobox,
   group memberships).
5. First login. `blueberry-firstboot-user.service` runs (brew bundle,
   user services). First-boot welcome kitty window appears.
6. Run guided setup, in any order:
   - `ujust enroll-yubikey`
   - `ujust enroll-fingerprint`
   - `ujust setup-wireguard`
   - `ujust setup-syncthing`
   - `ujust setup-usbguard`
   - `ujust framework-charge-limit`
7. Initialize chezmoi (`chezmoi init <repo> && chezmoi apply`).
8. Verify: `ujust verify-image`.

## Open questions / deferred decisions

1. **DanQing font for kitty** — falling back to JetBrainsMono Nerd
   Font; if a source surfaces, easy swap.
2. **Trusted SSIDs for WireGuard auto-connect** — populated
   post-install; not enumerated in spec.
3. **Initial USBGuard rules** — generated post-install via
   `ujust setup-usbguard` against a known-good plug-in set.
4. **Cosign keypair** — generated once before first push;
   `cosign.pub` committed, private key as `SIGNING_SECRET`.

## Out of scope

- NixOS hosts `oob` (RPi) and `small` (Mac).
- Multi-host blueberry variants beyond Framework AMD AI 300.
- chezmoi repo design (separate effort).
- Hardened browser (Trivalent), hardened_malloc, bubblejail.
- Auto-update timers.
- DNS-over-TLS / systemd-resolved.

## NixOS feature mapping (reference)

| NixOS module | Blueberry equivalent |
|---|---|
| `modules/linux/hardening.nix` (AppArmor) | SELinux enforcing (Fedora default) |
| `modules/linux/usbguard.nix` | USBGuard with `LinuxAudit` backend, rules.d static + rules.conf user-managed |
| `modules/linux/yubikey.nix` | `pcscd`, `pam_u2f cue=true`, `yubikey-touch-detector` |
| `modules/linux/keyring.nix` | `gnome-keyring` + greetd PAM, GnuPG agent SSH support |
| `modules/linux/journald.nix` | Same: `Storage=persistent` |
| `modules/linux/networking.nix` | NetworkManager + firewalld with localsend ports |
| `modules/linux/flatpak.nix` | `default-flatpaks` list + firstboot service |
| `modules/linux/fonts.nix` | RPM-layered Noto/JetBrains/Cantarell |
| `modules/linux/wayland.nix` | Sway, fuzzel, wl-clipboard, playerctl, grim, slurp; `xdg-desktop-portal-wlr` disabled |
| `modules/linux/wireguard.nix` | NM dispatcher script + `/etc/blueberry/wireguard/` config |
| `modules/linux/time.nix` | chrony with NTS + locale.conf |
| `modules/linux/email.nix` | ProtonMail Bridge as user service |
| `modules/linux/drawio.nix` | drawio Flatpak with `--enable-gpu-rasterization` override |
| `modules/linux/files.nix` | `thunar` (or Nautilus via Flatpak) |
| `modules/hardware/audio.nix` | PipeWire + WirePlumber + auto-switch |
| `modules/hardware/boot.nix` (Lanzaboote, LUKS modules) | Fedora-signed shim/GRUB + Anaconda LUKS |
| `modules/hardware/framework.nix` | `fwupd`, `fprintd`, `bolt`, mainline framework_laptop kmod |
| `modules/hardware/laptop.nix` | CalDigit dock unit + udev rule, lid behavior, power-profiles-daemon |
| `modules/hardware/wireless.nix` | Bluetooth masked at boot, blueman, regulatory db |
| `modules/hardware/ssd.nix` | `fstrim.timer`, `smartd` |
| `home/common/kitty.nix` | `/etc/xdg/kitty/kitty.conf` (image) + per-user `~/.config/kitty/` (chezmoi) |
| `home/linux/sway.nix` | `/etc/sway/config` (image) + `~/.config/sway/config.d/*` (chezmoi) |
| `home/linux/firefox.nix` | `/etc/firefox/policies/policies.json` + per-profile userChrome (chezmoi) |
| `home/linux/framework.nix` (DSP) | `/etc/easyeffects/output/cab-fw.json` |
| `home/linux/syncthing.nix` | User systemd unit, gated by `ujust setup-syncthing` |
| `home/linux/dconf.nix` | `gschema-overrides` |

---

## Acceptance criteria

The spec is implementable when all of the following are true:

1. `bootc switch ghcr.io/liana64/blueberry:latest` from a Fedora
   atomic base lands in a working sway session at next boot.
2. `ujust verify-image` reports a valid cosign signature.
3. The first-boot welcome appears in a kitty window after first
   login.
4. All listed Flatpaks are installed automatically.
5. The audit anomaly log emits zero events on a routine day with no
   anomalies, per the strict 0-baseline policy.
6. WireGuard auto-connect bringing `wg0` up on an untrusted SSID and
   tearing it down on a trusted SSID is observable end-to-end after
   `ujust setup-wireguard`.
7. The Framework charge limit set via `ujust framework-charge-limit`
   persists across reboot and resume.
8. The CalDigit TS4 sleep-inhibitor service activates on dock connect
   and exits on disconnect.
9. The bootable ISO produced by `build-disk.yml` installs Blueberry
   on bare metal with LUKS and yields the same end-state as the
   bootc-switch path.
10. `just build-qcow2 && just run-vm-qcow2` boots into a working sway
    session locally, end-to-end, without pushing.
