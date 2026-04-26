# Blueberry Spec Gap-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Each lane below is independent and can run in parallel via dispatching-parallel-agents. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Close the gap between `docs/specs/2026-04-25-blueberry-design.md` and the current build by porting the Sway desktop, security baseline, and reconciling `ujust` recipe naming. Niche hardware tweaks from `~/.dotfiles/home/linux/sway.nix` (touchpad/pointer/keyboard) ship as part of the Sway port.

**Architecture:** Bootc image, Fedora atomic. Configuration is materialized as static files under `system_files/` (copied verbatim by the Containerfile) and shell shards under `build_files/` (numbered, idempotent). Verification = `shellcheck`, `bootc container lint`, `just check`, and a VM smoke boot. There is no application code and no unit tests; "tests" here are file-presence + lint checks.

**Tech stack:** bash, sway IPC config syntax, waybar JSONC + CSS, mako INI, rofi rasi, systemd unit files, modprobe.d, sysctl.d, dracut.conf.d, just recipes, gum-themed shell helpers.

**Source of truth for ports:** `~/.dotfiles/home/linux/{sway,waybar,mako,rofi}.nix`, `~/.dotfiles/modules/hardware/{laptop,boot}.nix`. The dotfiles are the canonical user preference; spec is the canonical *system* shape.

---

## Lanes

Four independent lanes — Lane B subsumes Lane A's sway-input drop-in so they cannot both write to the same file. Lanes B/C/D have **no shared files** and can be dispatched in parallel.

| Lane | Scope | Files touched |
|---|---|---|
| A | Niche HW: dracut input_leds | `system_files/usr/lib/dracut/dracut.conf.d/` |
| B | Sway desktop port (sway + waybar + mako + rofi) | `system_files/etc/sway/`, `system_files/etc/xdg/{waybar,mako,rofi}/`, `build_files/20-sway.sh` |
| C | Security baseline (sysctl, modprobe, kargs, locale, services) | `system_files/etc/{sysctl.d,modprobe.d,locale.conf}`, `system_files/usr/lib/bootc/kargs.d/`, `build_files/10-services.sh` |
| D | `ujust` reconciliation | `system_files/usr/share/ublue-os/just/60-blueberry.just`, new `70-framework.just` |

---

## File Structure

**New files**

```
system_files/
├── usr/lib/dracut/dracut.conf.d/10-blueberry.conf            # Lane A
├── etc/sway/config                                           # Lane B
├── etc/sway/config.d/.gitkeep                                # Lane B
├── etc/xdg/waybar/config.jsonc                               # Lane B
├── etc/xdg/waybar/style.css                                  # Lane B
├── etc/xdg/mako/config                                       # Lane B
├── etc/xdg/rofi/config.rasi                                  # Lane B
├── etc/xdg/rofi/themes/blueberry.rasi                        # Lane B
├── etc/sysctl.d/99-blueberry-hardening.conf                  # Lane C
├── etc/modprobe.d/99-blueberry-blacklist.conf                # Lane C
├── etc/locale.conf                                           # Lane C
├── usr/lib/bootc/kargs.d/10-blueberry-hardening.toml         # Lane C
└── usr/share/ublue-os/just/70-framework.just                 # Lane D
```

**Modified files**

- `build_files/20-sway.sh` — Lane B (drop misleading no-op comment, add chmod for any helper scripts)
- `build_files/10-services.sh` — Lane C (mask abrt/avahi/cups-browsed/geoclue/packagekit, ensure xdg-desktop-portal-wlr not enabled)
- `system_files/usr/share/ublue-os/just/60-blueberry.just` — Lane D (rename recipes per spec, stub missing ones)

**Deliberately out of scope** (will be filed as follow-up gaps): Firefox `policies.json`, `/etc/xdg/kitty/kitty.conf`, fonts/MIME defaults, gschema-overrides, `/etc/environment`, full audit ruleset, PAM stack overrides, missing waybar custom helpers (`waybar-yubikey`, `waybar-syncthing`, `waybar-vpn`, `waybar-rpm-ostree`, `audit-summarize`, `motd-render`), Brewfile firstboot user service, `disk_config/iso-sway.toml`, GitHub Actions workflows, `docs/install.md` + `docs/MIGRATION.md`. The user picked lanes 1-4 from a menu; these are lanes 5+ and require a separate plan.

---

## Lane A — Niche HW

### Task A1: Dracut input_leds module for caps-lock LED at LUKS prompt

**Why:** Reproduces `~/.dotfiles/modules/hardware/boot.nix:40` — without `input_leds` in the initramfs, the caps-lock LED does not light up at the LUKS passphrase prompt, which is a real ergonomic loss for the user during boot.

**Files:**
- Create: `system_files/usr/lib/dracut/dracut.conf.d/10-blueberry.conf`

- [ ] **Step 1: Write the dracut drop-in**

```
# Include input_leds so the keyboard caps-lock LED works at the LUKS prompt.
# Mirrors NixOS modules/hardware/boot.nix initrd.luks.cryptoModules entry.
add_drivers+=" input_leds "
```

- [ ] **Step 2: Verify file was written and has correct path**

```bash
test -f system_files/usr/lib/dracut/dracut.conf.d/10-blueberry.conf
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add system_files/usr/lib/dracut/dracut.conf.d/10-blueberry.conf
git commit -m "feat(hw): add input_leds dracut module for LUKS caps-lock LED"
```

---

## Lane B — Sway desktop port

Single source of truth: `~/.dotfiles/home/linux/sway.nix`, `waybar.nix`, `mako.nix`, `rofi.nix`. The subagent must read these files first.

### Task B1: Port `/etc/sway/config`

**Why:** Spec §3 says `/etc/sway/config` is a "direct port" of `home/linux/sway.nix`. Currently absent — the only thing on disk that would launch a sway session is the package default. Includes the niche HW input block (touchpad tap/scroll, pointer accel, kbd repeat 200/40) the user specifically asked about.

**Files:**
- Create: `system_files/etc/sway/config`
- Create: `system_files/etc/sway/config.d/.gitkeep` (so `include /etc/sway/config.d/*` doesn't error on a missing dir)

**Translation rules from sway.nix → sway config syntax:**
- `extraConfig` block ports verbatim, but unwrap Nix interpolations: `${mbg}` etc. become literal hex from `~/.dotfiles/modules/common/colors/groove.nix` (subagent must read that file).
- The `app = pkgs.symlinkJoin { ... }` wrapper that builds `sway-screenshot-all`/`sway-screenshot-area` → drop. Those helpers don't ship in this image yet; replace the keybind targets with `grim`/`grim -g "$(slurp)"` inline equivalents per spec §3 (the spec-listed `sway-screenshot-all`/`area` are out of scope for this lane).
- `nix-rebuild-sway` keybind → drop entirely (NixOS-specific).
- `${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1` → `/usr/libexec/polkit-gnome-authentication-agent-1` (Fedora path).
- `autotiling-rs` → `/usr/bin/autotiling-rs` (built by `35-cargo.sh`, already on the image).
- `bibata-cursors` is RPM-packaged as `bibata-cursor-themes`; the cursor name `Bibata-Modern-Classic` matches.
- `home.pointerCursor` and `home.sessionVariables` from sway.nix go to `/etc/environment` — that file is **out of scope for this plan** (in the deferred list). Leave a comment in the sway config noting where those live.

- [ ] **Step 1: Read source files**

```bash
cat ~/.dotfiles/home/linux/sway.nix
cat ~/.dotfiles/modules/common/colors/groove.nix
```

- [ ] **Step 2: Write `/etc/sway/config` with literal port**

The file must contain these blocks in order: color set vars (with hex literals from groove.nix substituted), client.* color rules, `for_window` rules, `assign` rules, font, `seat * xcursor_theme`, lid bindswitch, `exec_always autotiling-rs`, swayidle exec, dbus-update-activation-environment exec, gnome-keyring exec, `set $mod Mod1`, `set $sup Mod4`, all keybindings (less the screenshot/nix-rebuild ones noted above), input config (touchpad/pointer/`*` blocks — verbatim including the niche tweaks), output config for eDP-1 and DP-5, bar with waybar, modes, `focus_follows_mouse no`, `focus_on_window_activation focus`, gaps inner 4 outer 4, smart_gaps on, smart_borders on, default_border pixel 2, default_floating_border pixel 2, titlebars off, polkit + kitty session startup execs.

End with: `include /etc/sway/config.d/*.conf`

- [ ] **Step 3: Validate sway config syntax**

Run: `sway -c system_files/etc/sway/config -C` (config-check mode; runs without compositor).
Expected: exit 0 with "Configuration loaded successfully."
If sway is not installed on the build host, defer this to the VM smoke test in Task B5.

- [ ] **Step 4: Create config.d placeholder**

```bash
touch system_files/etc/sway/config.d/.gitkeep
```

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/sway/config system_files/etc/sway/config.d/.gitkeep
git commit -m "feat(sway): add system /etc/sway/config ported from NixOS dotfiles"
```

### Task B2: Port `/etc/xdg/waybar/{config.jsonc,style.css}`

**Why:** Spec §3 ships waybar at `/etc/xdg/waybar/`; not present.

**Files:**
- Create: `system_files/etc/xdg/waybar/config.jsonc`
- Create: `system_files/etc/xdg/waybar/style.css`

**Translation notes:**
- Source: `~/.dotfiles/home/linux/waybar.nix`. It produces `~/.config/waybar/config` and `style.css` from Nix attrsets / strings.
- For `custom/*` modules whose helpers aren't shipped on the image (`waybar-yubikey`, `waybar-syncthing`, `waybar-vpn`, `waybar-rpm-ostree`): keep the module declarations in `config.jsonc` but point `exec` at a placeholder script `/usr/lib/blueberry/waybar/<name>` that emits valid JSON `{"text":"","class":"hidden","tooltip":""}` and exits 0. Also create that directory (subagent picks paths) — no, scratch that: simpler is to just *omit* those modules from the `modules-right` list for now and leave them defined but inactive. The image already has `waybar-usbguard` at `/usr/lib/blueberry/waybar/waybar-usbguard`, so wire that one up.
- Color palette: groove from `~/.dotfiles/modules/common/colors/groove.nix`. Must be substituted as hex literals in `style.css`.

- [ ] **Step 1: Read source**

```bash
cat ~/.dotfiles/home/linux/waybar.nix
cat ~/.dotfiles/modules/common/colors/groove.nix
```

- [ ] **Step 2: Write `config.jsonc`**

Top-level: `layer=top`, `position=top`, `height` matches NixOS, modules-left = `["custom/launcher", "sway/workspaces", "sway/mode"]`, modules-center = `["clock"]`, modules-right = `["custom/usbguard", "network", "battery", "bluetooth", "pulseaudio", "tray"]`. Wire `custom/usbguard` to `/usr/lib/blueberry/waybar/waybar-usbguard`. Keep options (battery warning=35 critical=15, bluetooth click → blueman-manager, pulseaudio click → pavucontrol) literally from waybar.nix.

- [ ] **Step 3: Write `style.css`**

Hex-substituted port of the CSS in waybar.nix. Font-family `JetBrainsMono Nerd Font`; if Fedora's RPM is `cascadia-mono-nf-fonts` (per `00-packages.sh`), include `Cascadia Mono NF` as the first fallback so glyphs render until JetBrainsMono ships.

- [ ] **Step 4: Validate JSONC**

Run: `jq --slurp 'tojson' system_files/etc/xdg/waybar/config.jsonc | head -c 1`

(`jsonc` allows `//` comments; if jq chokes, switch to `python -c "import json5; json5.load(open('...'))"` — `json5` likely not installed; skip and rely on waybar boot test in B5.)

- [ ] **Step 5: Commit**

```bash
git add system_files/etc/xdg/waybar/
git commit -m "feat(waybar): add system /etc/xdg/waybar config ported from NixOS dotfiles"
```

### Task B3: Port `/etc/xdg/mako/config`

**Files:**
- Create: `system_files/etc/xdg/mako/config`

- [ ] **Step 1: Read source**

```bash
cat ~/.dotfiles/home/linux/mako.nix
```

- [ ] **Step 2: Write config (mako INI format)**

`default-timeout=3000`, `border-radius=5`, `font=JetBrainsMono Nerd Font 10` (with Cascadia Mono NF fallback noted in a comment), groove palette colors substituted as hex.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/xdg/mako/config
git commit -m "feat(mako): add system /etc/xdg/mako/config ported from NixOS dotfiles"
```

### Task B4: Port `/etc/xdg/rofi/{config.rasi,themes/blueberry.rasi}`

**Files:**
- Create: `system_files/etc/xdg/rofi/config.rasi`
- Create: `system_files/etc/xdg/rofi/themes/blueberry.rasi`

- [ ] **Step 1: Read source**

```bash
cat ~/.dotfiles/home/linux/rofi.nix
```

- [ ] **Step 2: Write `config.rasi`**

Standard rasi: `configuration { modes: "drun"; show-icons: true; ... }` plus `@theme "blueberry"`.

- [ ] **Step 3: Write `themes/blueberry.rasi`**

Groove palette with hex literals, JetBrains Mono Nerd Font 12, 360px width, vertical listview (per spec §3).

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/xdg/rofi/
git commit -m "feat(rofi): add system /etc/xdg/rofi/ ported from NixOS dotfiles"
```

### Task B5: Update `build_files/20-sway.sh`

**Files:**
- Modify: `build_files/20-sway.sh`

The current file has a misleading comment. Replace with: a real comment block explaining the lane, plus any chmod/install commands needed (none today; helpers under `/usr/lib/blueberry/waybar/` are already chmodded by `30-hardware.sh`).

- [ ] **Step 1: Edit file to remove misleading comment**

```bash
#!/usr/bin/bash
echo "::group:: ===$(basename "$0")==="
set -eoux pipefail

# Sway desktop layer:
# - /etc/sway/config (system_files)
# - /etc/xdg/{waybar,mako,rofi}/ (system_files)
# - /etc/sway/config.d/ user drop-in directory (system_files)
# Helpers under /usr/lib/blueberry/waybar/ are made executable by
# 30-hardware.sh together with the other libexec scripts.

echo "::endgroup::"
```

- [ ] **Step 2: shellcheck**

Run: `shellcheck build_files/20-sway.sh`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add build_files/20-sway.sh
git commit -m "chore(sway): replace stale comment with accurate lane summary"
```

### Task B6: Build smoke test (Lane B integration)

- [ ] **Step 1: Build image**

Run: `just build`
Expected: success, no `bootc container lint` errors.

- [ ] **Step 2: Verify files in image**

```bash
podman run --rm localhost/blueberry:latest ls -la \
  /etc/sway/config /etc/xdg/waybar/config.jsonc /etc/xdg/mako/config /etc/xdg/rofi/config.rasi
```

Expected: all four exist, mode 0644, root:root.

- [ ] **Step 3: VM boot (manual gate)**

Run: `just build-qcow2 && just run-vm-qcow2`. Expected: greetd → tuigreet → sway session. Touchpad tap-to-click works. Caps-lock LED behavior unrelated here (Lane A).

(This step is a manual gate — flag if not already green and let the user run it.)

---

## Lane C — Security baseline

Independent of B/D — different files. Spec §2 is the source.

### Task C1: Sysctl hardening

**Files:**
- Create: `system_files/etc/sysctl.d/99-blueberry-hardening.conf`

- [ ] **Step 1: Write file**

```
# Spec §2 — security baseline
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

- [ ] **Step 2: Commit**

```bash
git add system_files/etc/sysctl.d/99-blueberry-hardening.conf
git commit -m "feat(security): add sysctl hardening drop-in"
```

### Task C2: Module blacklist

**Files:**
- Create: `system_files/etc/modprobe.d/99-blueberry-blacklist.conf`

- [ ] **Step 1: Write file**

```
# Spec §2 — never auto-load these (FireWire, niche FSes, niche network protos).
install firewire-core /bin/true
install firewire-ohci /bin/true
install firewire-sbp2 /bin/true
install udf /bin/true
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install cifs /bin/true
install nfs /bin/true
install nfsv3 /bin/true
install nfsv4 /bin/true
install ksmbd /bin/true
install gfs2 /bin/true
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
```

(Using `install ... /bin/true` rather than `blacklist` — this prevents both auto-load *and* explicit `modprobe`; matches what most hardening guides recommend.)

- [ ] **Step 2: Commit**

```bash
git add system_files/etc/modprobe.d/99-blueberry-blacklist.conf
git commit -m "feat(security): blacklist firewire and niche fs/net modules"
```

### Task C3: Kernel cmdline hardening

**Files:**
- Create: `system_files/usr/lib/bootc/kargs.d/10-blueberry-hardening.toml`

(Distinct from existing `00-blueberry.toml` which carries AMD GPU kargs — keep concerns separated.)

- [ ] **Step 1: Write file**

```toml
# Spec §2 — kernel cmdline hardening
kargs = [
    "lockdown=confidentiality",
    "module.sig_enforce=1",
    "init_on_alloc=1",
    "init_on_free=1",
    "page_alloc.shuffle=1",
    "randomize_kstack_offset=on",
    "vsyscall=none",
    "mitigations=auto,nosmt",
]
```

(No `match-architectures`: these apply to both x86_64 and aarch64 — though blueberry only targets x86_64 today, omitting the filter means a future arch port inherits the kargs by default.)

- [ ] **Step 2: Commit**

```bash
git add system_files/usr/lib/bootc/kargs.d/10-blueberry-hardening.toml
git commit -m "feat(security): add hardening kargs (lockdown, init_on_*, kstack, vsyscall=none)"
```

### Task C4: Locale

**Files:**
- Create: `system_files/etc/locale.conf`

(Skip `/etc/localtime` — it's a symlink and `bootc-image-builder` sets it. Document the expected target as `America/Chicago` in the install doc, deferred.)

- [ ] **Step 1: Write file**

```
LANG=en_US.UTF-8
LC_ADDRESS=en_US.UTF-8
LC_IDENTIFICATION=en_US.UTF-8
LC_MEASUREMENT=en_US.UTF-8
LC_MONETARY=en_US.UTF-8
LC_NAME=en_US.UTF-8
LC_NUMERIC=en_US.UTF-8
LC_PAPER=en_US.UTF-8
LC_TELEPHONE=en_US.UTF-8
LC_TIME=en_US.UTF-8
```

- [ ] **Step 2: Commit**

```bash
git add system_files/etc/locale.conf
git commit -m "feat(locale): set en_US.UTF-8 LANG and LC_* defaults"
```

### Task C5: Mask defunct services in `10-services.sh`

**Files:**
- Modify: `build_files/10-services.sh`

Append a "mask spec-disabled services" block. Use `mask` (not `disable`) so user enabling fails until they explicitly unmask — matches spec §2 "Disabled services" intent.

- [ ] **Step 1: Read current file, then add at end (before `echo "::endgroup::"`)**

```bash
# Spec §2 — services that must never run on Blueberry by default.
# Some of these are not installed on base-main; `|| true` keeps the build
# idempotent across base image churn.
for svc in avahi-daemon.service cups-browsed.service geoclue.service \
           packagekit.service abrt-journal-core.service abrt-oops.service \
           abrt-vmcore.service abrt-xorg.service abrtd.service \
           xdg-desktop-portal-wlr.service; do
    systemctl mask "$svc" || true
done
```

- [ ] **Step 2: shellcheck**

Run: `shellcheck build_files/10-services.sh`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add build_files/10-services.sh
git commit -m "feat(services): mask avahi/cups-browsed/geoclue/packagekit/abrt/xdp-wlr"
```

### Task C6: Lane C build smoke test

- [ ] **Step 1: Build image**

Run: `just build`
Expected: success, lint clean.

- [ ] **Step 2: Verify files**

```bash
podman run --rm localhost/blueberry:latest sh -c '
  ls /etc/sysctl.d/99-blueberry-hardening.conf \
     /etc/modprobe.d/99-blueberry-blacklist.conf \
     /usr/lib/bootc/kargs.d/10-blueberry-hardening.toml \
     /etc/locale.conf
  systemctl is-enabled avahi-daemon.service 2>&1 | grep -q masked && echo MASKED-OK
'
```

Expected: all 4 files exist + MASKED-OK printed.

---

## Lane D — `ujust` reconciliation

Source of truth: spec §6 "ujust commands" list. Current file: `system_files/usr/share/ublue-os/just/60-blueberry.just`. Discrepancies:

| Spec name | Current name (if any) | Action |
|---|---|---|
| `update` | `update` | keep |
| `rollback` | `rollback` | keep |
| `verify-image` | `verify-image` | keep |
| `enroll-fingerprint` | `enroll-fingerprint` | keep |
| `framework-charge-limit` | `toggle-charge-limit` | rename + make interactive (gum input 60-100) |
| `framework-firmware-update` | — | stub: `fwupdmgr refresh && fwupdmgr update` wrapped in gum |
| `framework-dsp-on` / `framework-dsp-off` | — | stub: touch/remove `/var/lib/blueberry/dsp.enabled` marker (firstboot user service consumes — that service is out of scope; stub still useful) |
| `dock-status` | — | stub: `boltctl list` filtered for CalDigit |
| `enable-screencast` / `disable-screencast` | `install-screencast` (one-way) | rename + add disable counterpart |
| `enroll-yubikey` | — | stub: `pamu2fcfg >> ~/.config/Yubico/u2f_keys` flow with gum |
| `setup-wireguard` | — | stub: gum write into `/etc/blueberry/wireguard/{wg0.conf,trusted-networks}` via pkexec |
| `setup-syncthing` | — | stub: `systemctl --user enable --now syncthing` + firewall ports |
| `setup-usbguard` | — | stub: `usbguard generate-policy > /etc/usbguard/rules.conf` via pkexec |
| `toggle-bluetooth` | — | stub: invert `bluetooth.service` enabled state |
| `toggle-devmode` | — | stub: gum confirm + `rpm-ostree usroverlay` semantics |
| `install-cider` | — | stub: distrobox `apps-cider` create + `distrobox-export` |
| `install-extras` | — | stub: gum choose menu over an empty list (real list deferred) |
| `audit-summary` | `anomalies` | rename |
| `factory-reset` | — | stub: gum confirm + `rpm-ostree reset` |
| `changelog` | — | stub: diff `org.opencontainers.image.created` between deployments |
| `motd` | — | stub: cat `/etc/profile.d/blueberry-motd.sh` (real renderer deferred) |
| `fix-flatpak-permissions` | — | stub: `flatpak repair --user` |
| (none) | `assemble-distrobox` | keep — spec doesn't list it but it's useful |
| (none) | `enroll-fido2` | keep — useful, spec is silent |
| (none) | `enroll-secure-boot` | keep |
| (none) | `clean` | keep |
| (none) | `brew-bundle` | keep |

**Stub conventions:** each new recipe starts with the same `gum-theme.sh` source + `bb_header` line, ends with `bb_ok`/`bb_warn`, and may print `bb_warn "stub — full implementation tracked in TODO"` in the body if the underlying machinery (e.g. `/etc/blueberry/wireguard/` directory permissions, audit summarizer binary) is deferred. The point of a stub is that the recipe *exists* and is discoverable via `ujust`; the body need not be production-grade yet.

### Task D1: Rename `toggle-charge-limit` → `framework-charge-limit`

**Files:**
- Modify: `system_files/usr/share/ublue-os/just/60-blueberry.just`

- [ ] **Step 1: Replace recipe**

Replace the `toggle-charge-limit:` block with `framework-charge-limit:` that prompts via `gum input --placeholder "60-100"`, validates 60 ≤ N ≤ 100, writes to `/sys/class/power_supply/BAT1/charge_control_end_threshold` via sudo (the existing systemd unit re-applies on resume).

- [ ] **Step 2: just check**

Run: `just check`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add system_files/usr/share/ublue-os/just/60-blueberry.just
git commit -m "refactor(just): rename toggle-charge-limit → framework-charge-limit (interactive)"
```

### Task D2: Rename `install-screencast` → `enable-screencast` + add `disable-screencast`

**Files:**
- Modify: `system_files/usr/share/ublue-os/just/60-blueberry.just`

- [ ] **Step 1: Rename + add counterpart**

`enable-screencast` body unchanged (rpm-ostree install xdg-desktop-portal-wlr + reboot prompt).
`disable-screencast` body: `sudo rpm-ostree uninstall xdg-desktop-portal-wlr` (no-op if not layered) + reboot prompt.

- [ ] **Step 2: just check**

Run: `just check`. Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add system_files/usr/share/ublue-os/just/60-blueberry.just
git commit -m "refactor(just): split install-screencast into enable/disable pair"
```

### Task D3: Rename `anomalies` → `audit-summary`

**Files:**
- Modify: `system_files/usr/share/ublue-os/just/60-blueberry.just`

- [ ] **Step 1: Rename, body unchanged**

- [ ] **Step 2: just check + commit**

```bash
git add system_files/usr/share/ublue-os/just/60-blueberry.just
git commit -m "refactor(just): rename anomalies → audit-summary per spec"
```

### Task D4: Add stub recipes (one commit per logical group)

**Files:**
- Modify: `system_files/usr/share/ublue-os/just/60-blueberry.just`

Use `[group('...')]` annotations so `ujust` lists them in coherent sections. Ship four logical groups:

1. **Lifecycle:** `factory-reset`, `changelog`, `motd`, `fix-flatpak-permissions`
2. **First-time setup:** `setup-wireguard`, `setup-syncthing`, `setup-usbguard`, `enroll-yubikey`
3. **Toggles:** `toggle-bluetooth`, `toggle-devmode`, `install-cider`, `install-extras`

Each stub has the gum-theme header + a body that either does the obvious thing (e.g. `setup-syncthing` is `systemctl --user enable --now syncthing && sudo firewall-cmd --add-port=22000/tcp --permanent && ... && firewall-cmd --reload`) or prints `bb_warn "stub — see TODO"` and exits 0. Stubs *must* be runnable without crashing.

- [ ] **Step 1: Append lifecycle group**

(Concrete code for `factory-reset`: gum confirm → `sudo rpm-ostree reset`. `changelog`: `rpm-ostree status` + `jq` to print `.deployments[0].timestamp` and `.deployments[1].timestamp`. `motd`: re-render via `/etc/profile.d/blueberry-motd.sh`. `fix-flatpak-permissions`: `flatpak repair --user || true`.)

- [ ] **Step 2: just check + commit lifecycle**

```bash
git add system_files/usr/share/ublue-os/just/60-blueberry.just
git commit -m "feat(just): add lifecycle stubs (factory-reset, changelog, motd, fix-flatpak-permissions)"
```

- [ ] **Step 3: Append setup group + just check + commit**

```bash
git commit -m "feat(just): add first-time-setup stubs (wireguard, syncthing, usbguard, yubikey)"
```

- [ ] **Step 4: Append toggles group + just check + commit**

```bash
git commit -m "feat(just): add toggle stubs (bluetooth, devmode, cider, extras)"
```

### Task D5: Create `70-framework.just`

**Files:**
- Create: `system_files/usr/share/ublue-os/just/70-framework.just`

Move Framework-specific recipes here per spec §6: `framework-charge-limit`, `framework-firmware-update`, `framework-dsp-on`, `framework-dsp-off`, `dock-status`. Stubs as described in the table above.

- [ ] **Step 1: Write file**

(Concrete code: `framework-firmware-update` → gum spin around `fwupdmgr refresh -y` then `fwupdmgr update -y`. `framework-dsp-on/off` → `sudo touch/rm /var/lib/blueberry/dsp.enabled`. `dock-status` → `boltctl list | grep -A6 CalDigit || bb_warn "no CalDigit dock detected"`.)

- [ ] **Step 2: Move `framework-charge-limit` from `60-` to `70-`**

Edit `60-blueberry.just` to delete the recipe; place it in `70-framework.just`.

- [ ] **Step 3: just check**

Run: `just check`
Expected: clean across both files.

- [ ] **Step 4: Commit**

```bash
git add system_files/usr/share/ublue-os/just/{60-blueberry.just,70-framework.just}
git commit -m "feat(just): split framework recipes into 70-framework.just"
```

### Task D6: Lane D smoke test

- [ ] **Step 1: Build image**

Run: `just build`. Expected: lint clean.

- [ ] **Step 2: Run ujust list inside container**

```bash
podman run --rm localhost/blueberry:latest ujust --list
```

Expected: prints the spec recipe names — at minimum `update`, `rollback`, `verify-image`, `framework-charge-limit`, `framework-firmware-update`, `framework-dsp-on`, `framework-dsp-off`, `dock-status`, `enable-screencast`, `disable-screencast`, `audit-summary`, `factory-reset`, `changelog`, `motd`, `fix-flatpak-permissions`, `setup-wireguard`, `setup-syncthing`, `setup-usbguard`, `enroll-yubikey`, `enroll-fingerprint`, `toggle-bluetooth`, `toggle-devmode`, `install-cider`, `install-extras`.

---

## Self-review checklist (run after all lanes complete)

- [ ] Spec §2 sysctl, modprobe, kargs, locale all materialized? — Lane C tasks 1-4
- [ ] Spec §2 disabled services masked? — Lane C task 5
- [ ] Spec §3 sway/waybar/mako/rofi all present? — Lane B tasks 1-4
- [ ] Niche HW input block in sway config? — Lane B task 1 (touchpad/pointer/`*` blocks)
- [ ] Caps-lock LED at LUKS prompt? — Lane A task 1
- [ ] Spec §6 `ujust` recipe names match? — Lane D tasks 1-5
- [ ] All listed deferred items still deferred (Firefox, kitty, fonts, etc.)? — confirm none accidentally implemented
- [ ] All commits clean (one logical change each, no `--no-verify`)?
- [ ] `just build` green at HEAD? — Lane B6 + C6 + D6 smoke tests
