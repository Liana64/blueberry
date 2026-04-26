# Blueberry Static-Files Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Each lane is independent and can run in parallel via dispatching-parallel-agents. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship the static-file deferred items from `2026-04-26-spec-gap-fill.md` (lanes E/F/G/J): `/etc/environment`, kitty system config, gschema-overrides, MIME defaults, Firefox enterprise policies, custom authselect profile + swaylock PAM, and `disk_config/iso-sway.toml`.

**Architecture:** Bootc image, Fedora atomic. Configuration is materialized as static files under `system_files/` and `disk_config/` (copied verbatim by the Containerfile). Lane G adds one new build-script shard `build_files/45-authselect.sh` that activates the custom authselect profile at image-build time. Verification = `shellcheck`, `bootc container lint`, file-presence checks via `podman run`. There is no application code and no unit tests.

**Tech stack:** kitty conf format, glib gschema-override INI, freedesktop mimeapps INI, Mozilla enterprise policies JSON schema, authselect profile (PAM templates), bootc-image-builder TOML.

**Source of truth for ports:** `~/.dotfiles/home/common/kitty.nix`, `~/.dotfiles/home/linux/{firefox,dconf}.nix`, `docs/specs/2026-04-25-blueberry-design.md`, `docs/specs/2026-04-26-static-files-batch-design.md`.

---

## Lanes

Four independent lanes, all path-disjoint. No shared files. All can be dispatched in parallel.

| Lane | Scope | Files touched |
|---|---|---|
| E | Desktop polish (env, kitty, dconf, MIME) | `system_files/etc/environment`, `system_files/etc/xdg/kitty/`, `system_files/usr/share/glib-2.0/schemas/`, `system_files/usr/share/applications/` |
| F | Firefox enterprise policies | `system_files/etc/firefox/policies/`, `system_files/etc/flatpak/overrides/` |
| G | Custom authselect profile + swaylock PAM | `system_files/etc/authselect/custom/blueberry/`, `system_files/etc/pam.d/swaylock`, `build_files/45-authselect.sh` |
| J | ISO sway disk config | `disk_config/iso-sway.toml` |

---

## File Structure

**New files**

```
build_files/
└── 45-authselect.sh                                              # Lane G

disk_config/
└── iso-sway.toml                                                 # Lane J

system_files/
├── etc/
│   ├── authselect/custom/blueberry/
│   │   ├── README                                                # Lane G
│   │   ├── system-auth                                           # Lane G
│   │   ├── password-auth                                         # Lane G
│   │   ├── fingerprint-auth                                      # Lane G
│   │   ├── smartcard-auth                                        # Lane G
│   │   ├── postlogin                                             # Lane G
│   │   └── nsswitch.conf                                         # Lane G
│   ├── environment                                               # Lane E
│   ├── firefox/policies/policies.json                            # Lane F
│   ├── flatpak/overrides/org.mozilla.firefox                     # Lane F
│   ├── pam.d/swaylock                                            # Lane G
│   └── xdg/kitty/kitty.conf                                      # Lane E
└── usr/share/
    ├── applications/mimeapps.list                                # Lane E
    └── glib-2.0/schemas/99-blueberry.gschema.override            # Lane E
```

**Modified files:** none. (`build_files/45-authselect.sh` is new, slotted between `40-flatpaks.sh` and `50-ujust.sh`.)

---

## Lane E — Desktop polish

Independent of B/F/G/J. Four sub-tasks, one commit per file.

### Task E1: `/etc/environment`

**Why:** Spec §3 lines 492-508 lists the env vars the sway session expects. Without them, Wayland-native flags (`MOZ_ENABLE_WAYLAND`, `QT_QPA_PLATFORM`) are missing and apps fall back to XWayland or break entirely.

**Files:**
- Create: `system_files/etc/environment`

- [ ] **Step 1: Write the file**

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

- [ ] **Step 2: Verify**

Run: `test -f system_files/etc/environment && grep -q MOZ_ENABLE_WAYLAND system_files/etc/environment`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/environment
git commit -m "feat(env): ship /etc/environment with wayland-native session vars"
```

### Task E2: `/etc/xdg/kitty/kitty.conf`

**Why:** Spec §3 lines 455-461 ships kitty's system-wide config at `/etc/xdg/kitty/kitty.conf`. Without this, kitty uses its compiled-in defaults — wrong palette, wrong font, no scrollback, no tab session.

**Source of truth:** `~/.dotfiles/home/common/kitty.nix` (~127 LoC). Translation: Nix attrset → kitty INI-ish syntax. Keep all keybindings, the 7-tab `startup.session` (home/dev/ai/mon/ctl/rmt/perf), Dracula palette, font config, beam cursor, scrollback 200000.

**Files:**
- Create: `system_files/etc/xdg/kitty/kitty.conf`

- [ ] **Step 1: Read the source**

Run: `cat ~/.dotfiles/home/common/kitty.nix`
Read the entire file. Note three sections: `programs.kitty.settings`, `programs.kitty.keybindings`, and the `extraConfig` block (which contains the `startup.session` definition).

- [ ] **Step 2: Translate to kitty conf format**

Translation rules:
- `settings.<key> = "value"` → `<key> value` (e.g., `font_family JetBrainsMono Nerd Font`)
- `settings.<key> = N` (number) → `<key> N`
- `settings.<key> = true|false` → `<key> yes|no`
- `keybindings."ctrl+a"."new_tab"` → `map ctrl+a new_tab`
- The 7-tab `startup.session` is written **inline at the bottom of `kitty.conf`** as a series of `launch --type=tab --tab-title=<name> <command>` lines (kitty supports this without a separate session file). Translate each NixOS session entry (home/dev/ai/mon/ctl/rmt/perf) into one `launch` line preserving the cwd and command.
- The `font_family` is `JetBrainsMono Nerd Font` with `Cascadia Mono NF` as the symbol fallback (consistent with mako/waybar/rofi font note from Lane B).

Write the resulting file.

- [ ] **Step 3: Verify file presence + minimal lint**

Run:
```bash
test -f system_files/etc/xdg/kitty/kitty.conf
grep -q '^font_family' system_files/etc/xdg/kitty/kitty.conf
grep -q '^map ' system_files/etc/xdg/kitty/kitty.conf
grep -q '^launch ' system_files/etc/xdg/kitty/kitty.conf
```
Expected: all exit 0.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/xdg/kitty/kitty.conf
git commit -m "feat(kitty): ship system /etc/xdg/kitty/kitty.conf ported from NixOS"
```

### Task E3: gschema-override

**Why:** Spec §3 line 476 specifies dconf defaults via gschema-overrides for file-chooser sort/show-hidden + `color-scheme=prefer-dark`. Without this, GTK file pickers default to alphabetical-without-dirs-first and the GTK4 dark theme is not auto-applied.

**Source of truth:** `~/.dotfiles/home/linux/dconf.nix` (17 LoC). Implementer reads it for the full setting list before writing the override.

**Files:**
- Create: `system_files/usr/share/glib-2.0/schemas/99-blueberry.gschema.override`

- [ ] **Step 1: Read source**

Run: `cat ~/.dotfiles/home/linux/dconf.nix`
The file contains a `dconf.settings` attrset keyed by schema (e.g., `"org/gtk/Settings/FileChooser"`).

- [ ] **Step 2: Write the override**

Format is INI; section header is the dotted schema id (NOT the slashed dconf path). Example:

```
[org.gtk.Settings.FileChooser]
show-hidden=true
sort-directories-first=true

[org.gnome.desktop.interface]
color-scheme='prefer-dark'
```

(String values are single-quoted; booleans are bare `true`/`false`; numbers bare. This differs from dconf path syntax — converting from `dconf.nix`'s `"org/foo/bar"` keys to the dotted form is required.)

Include every schema key from `dconf.nix`. If the source has settings outside the GTK/GNOME interface (e.g., nautilus, mutter), include them.

- [ ] **Step 3: Verify**

Run:
```bash
test -f system_files/usr/share/glib-2.0/schemas/99-blueberry.gschema.override
grep -q "^\[org\." system_files/usr/share/glib-2.0/schemas/99-blueberry.gschema.override
```
Expected: exit 0.

(`glib-compile-schemas` runs automatically during RPM install for any package shipping under that path; the override is picked up at image build time without explicit invocation. If `bootc container lint` complains about uncompiled schemas, add `glib-compile-schemas /usr/share/glib-2.0/schemas/` to `60-branding.sh` as a follow-up — but lint should not complain because the override is just a drop-in to an already-compiled directory tree.)

- [ ] **Step 4: Commit**

```bash
git add system_files/usr/share/glib-2.0/schemas/99-blueberry.gschema.override
git commit -m "feat(dconf): add gschema-override for file-chooser + dark color-scheme"
```

### Task E4: System-wide MIME defaults

**Why:** Spec §5 line 608-611 specifies HTML/HTTP/HTTPS/PDF → Firefox; terminal → Kitty; text/plain → GNOME Text Editor; images → GNOME Loupe. Without this, `xdg-open` falls back to per-mime defaults that depend on package install order.

**Files:**
- Create: `system_files/usr/share/applications/mimeapps.list`

- [ ] **Step 1: Write file**

```
[Default Applications]
text/html=org.mozilla.firefox.desktop
application/xhtml+xml=org.mozilla.firefox.desktop
x-scheme-handler/http=org.mozilla.firefox.desktop
x-scheme-handler/https=org.mozilla.firefox.desktop
application/pdf=org.mozilla.firefox.desktop
x-scheme-handler/terminal=kitty.desktop
text/plain=org.gnome.TextEditor.desktop
image/png=org.gnome.Loupe.desktop
image/jpeg=org.gnome.Loupe.desktop
image/gif=org.gnome.Loupe.desktop
image/webp=org.gnome.Loupe.desktop
image/svg+xml=org.gnome.Loupe.desktop
```

(Firefox is a Flatpak; its `.desktop` lives at `/var/lib/flatpak/exports/share/applications/org.mozilla.firefox.desktop`, which is in `XDG_DATA_DIRS`. The mimeapps binding works against the desktop-id — `org.mozilla.firefox.desktop` — not the path.)

- [ ] **Step 2: Verify**

Run:
```bash
test -f system_files/usr/share/applications/mimeapps.list
grep -q '^text/html=' system_files/usr/share/applications/mimeapps.list
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add system_files/usr/share/applications/mimeapps.list
git commit -m "feat(mime): set system-wide defaults (firefox/kitty/text-editor/loupe)"
```

---

## Lane F — Firefox enterprise policies

Independent of E/G/J. Single deliverable + one prerequisite override.

### Task F1: `/etc/firefox/policies/policies.json`

**Why:** Spec §5 lines 590-606 enumerates the Firefox policies — telemetry off, tracking protection, HTTPS-only, search engines (Kagi default + custom additions, Bing removed), VAAPI prefs, extension installs (Sidebery + uBlock Origin). Honored by the Firefox Flatpak via the system-policies path.

**Source of truth:** `~/.dotfiles/home/linux/firefox.nix` (291 LoC). Subagent reads it for exact values.

**Files:**
- Create: `system_files/etc/firefox/policies/policies.json`

- [ ] **Step 1: Read source**

Run: `cat ~/.dotfiles/home/linux/firefox.nix`
The file is a Nix expression with a `firefox.policies` attrset that maps almost 1:1 onto Mozilla's enterprise policies JSON schema. Note four sub-blocks: top-level booleans/strings, `Preferences`, `SearchEngines`, `ExtensionSettings`.

- [ ] **Step 2: Write `policies.json`**

Wrap the result in `{"policies": { ... }}`. Convert: Nix bools → JSON bools, Nix strings → JSON strings (escape `/` if needed), Nix lists → JSON arrays, Nix attrsets → JSON objects. The keys map directly: `firefox.policies.DisableTelemetry = true` → `"DisableTelemetry": true`.

Required key categories (subagent uses `firefox.nix` for canonical values):

- **Telemetry off**: `DisableTelemetry`, `DisableFirefoxStudies`, plus the `Preferences` block pinning `toolkit.telemetry.*` and `datareporting.*` to false with `Status="locked"`.
- **Disabled UX features**: `DisablePocket`, `DisableAccounts`, `DisableFirefoxAccounts`, `DontCheckDefaultBrowser`, `OverrideFirstRunPage = ""`, `OverridePostUpdatePage = ""`.
- **Privacy/security**: `EnableTrackingProtection = {"Value": true, "Locked": true}`, `HttpsOnlyMode = "enabled"`.
- **Branding**: `Homepage = {"URL": "https://labs.lianas.org", "StartPage": "homepage"}`.
- **Search**: `SearchEngines = {"Default": "Kagi", "Add": [ ... ], "Remove": ["Bing"]}` with engines Kagi, GitHub, Flathub, Kubesearch, Nixpkgs, Nix Options, OpenSecrets — exact URL/Method/IconURL fields per `firefox.nix`.
- **GPU/VAAPI**: `Preferences` entries:
  - `gfx.webrender.all`: `{"Value": true, "Status": "locked"}`
  - `media.ffmpeg.vaapi.enabled`: same
  - `widget.dmabuf.force-enabled`: same
- **Extensions**: `ExtensionSettings` keyed by extension id. For each of Sidebery (`{3c078156-979c-498b-8990-85f7987dd929}`) and uBlock Origin (`uBlock0@raymondhill.net`):
  ```json
  {
    "installation_mode": "force_installed",
    "install_url": "https://addons.mozilla.org/firefox/downloads/latest/<slug>/latest.xpi"
  }
  ```

- [ ] **Step 3: Validate JSON**

Run: `jq . system_files/etc/firefox/policies/policies.json > /dev/null`
Expected: exit 0 (valid JSON). If `jq` errors, fix the syntax.

- [ ] **Step 4: Commit**

```bash
git add system_files/etc/firefox/policies/policies.json
git commit -m "feat(firefox): ship enterprise policies (telemetry off, tracking, search, extensions)"
```

### Task F2: Flatpak override for `/etc/firefox` read-only mount

**Why:** The Firefox Flatpak is sandboxed; without `--filesystem=/etc/firefox:ro`, it cannot read `/etc/firefox/policies/policies.json` and the policies above are silently ignored.

**Files:**
- Create: `system_files/etc/flatpak/overrides/org.mozilla.firefox`

- [ ] **Step 1: Write override**

```
[Context]
filesystems=/etc/firefox:ro
```

(This is the freedesktop.org `flatpak-config-info(5)` format. Matches what `flatpak override --user --filesystem=/etc/firefox:ro org.mozilla.firefox` would write.)

- [ ] **Step 2: Verify**

Run:
```bash
test -f system_files/etc/flatpak/overrides/org.mozilla.firefox
grep -q "^filesystems=/etc/firefox:ro" system_files/etc/flatpak/overrides/org.mozilla.firefox
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/flatpak/overrides/org.mozilla.firefox
git commit -m "feat(flatpak): mount /etc/firefox:ro into firefox sandbox for policies"
```

### Task F3: Lane F build smoke test

- [ ] **Step 1: Build image**

Run: `just build`
Expected: success, no `bootc container lint` errors.

- [ ] **Step 2: Verify files in image**

```bash
podman run --rm localhost/blueberry:latest sh -c '
  test -f /etc/firefox/policies/policies.json &&
  test -f /etc/flatpak/overrides/org.mozilla.firefox &&
  jq -e .policies.DisableTelemetry /etc/firefox/policies/policies.json &&
  echo OK
'
```
Expected: prints `true` then `OK`.

---

## Lane G — Custom authselect profile + swaylock PAM

Independent of E/F/J. One conceptual change, three sub-tasks (clone profile, write swaylock pam, wire build script). Single commit per task.

### Task G1: Clone Fedora's `sssd` profile, modify for u2f + faillock

**Why:** Spec §2 lines 268-275 specifies `pam_u2f cue=true` on sudo/login/swaylock, `pam_faillock` on local logins, fingerprint opt-in. Spec design `2026-04-26-static-files-batch-design.md` chose authselect-based delivery so changes survive `authselect apply-changes`.

**Files:**
- Create: `system_files/etc/authselect/custom/blueberry/system-auth`
- Create: `system_files/etc/authselect/custom/blueberry/password-auth`
- Create: `system_files/etc/authselect/custom/blueberry/fingerprint-auth`
- Create: `system_files/etc/authselect/custom/blueberry/smartcard-auth`
- Create: `system_files/etc/authselect/custom/blueberry/postlogin`
- Create: `system_files/etc/authselect/custom/blueberry/nsswitch.conf`
- Create: `system_files/etc/authselect/custom/blueberry/README`

- [ ] **Step 1: Extract Fedora's stock `sssd` profile from a base container**

Run:
```bash
mkdir -p /tmp/authselect-sssd
podman run --rm fedora:latest sh -c '
  cd /usr/share/authselect/default/sssd && tar c .
' | tar x -C /tmp/authselect-sssd
ls /tmp/authselect-sssd
```
Expected: prints `system-auth password-auth fingerprint-auth smartcard-auth postlogin nsswitch.conf README`.

- [ ] **Step 2: Copy unmodified files into the custom profile**

```bash
mkdir -p system_files/etc/authselect/custom/blueberry
cp /tmp/authselect-sssd/{fingerprint-auth,smartcard-auth,postlogin,nsswitch.conf} \
   system_files/etc/authselect/custom/blueberry/
```

- [ ] **Step 3: Write `system-auth` with pam_u2f and pam_faillock additions**

Read the source:
```bash
cat /tmp/authselect-sssd/system-auth
```

The stock file has an `auth` section that looks roughly like:

```
auth        required                                     pam_env.so
auth        required                                     pam_faildelay.so delay=2000000
{include if "with-faillock"}
auth        required                                     pam_faillock.so preauth silent deny=4 unlock_time=1200
{end if}
{include if "with-fingerprint"}
auth        [success=done ignore=ignore default=bad]     pam_fprintd.so
{end if}
auth        sufficient                                   pam_unix.so {if not "without-nullok":nullok}
auth        sufficient                                   pam_sss.so forward_pass
{include if "with-faillock"}
auth        [default=die]                                pam_faillock.so authfail
auth        sufficient                                   pam_faillock.so authsucc
{end if}
auth        required                                     pam_deny.so
```

Insert a u2f line **before `pam_unix`**, gated on `with-pam-u2f-2fa`. Result:

```
auth        required                                     pam_env.so
auth        required                                     pam_faildelay.so delay=2000000
{include if "with-faillock"}
auth        required                                     pam_faillock.so preauth silent deny=4 unlock_time=1200
{end if}
{include if "with-fingerprint"}
auth        [success=done ignore=ignore default=bad]     pam_fprintd.so
{end if}
{include if "with-pam-u2f-2fa"}
auth        sufficient                                   pam_u2f.so cue
{end if}
auth        sufficient                                   pam_unix.so {if not "without-nullok":nullok}
auth        sufficient                                   pam_sss.so forward_pass
{include if "with-faillock"}
auth        [default=die]                                pam_faillock.so authfail
auth        sufficient                                   pam_faillock.so authsucc
{end if}
auth        required                                     pam_deny.so
```

(Keep all other sections — `account`, `password`, `session` — exactly as in the stock file.)

Write to `system_files/etc/authselect/custom/blueberry/system-auth`.

- [ ] **Step 4: Write `password-auth` with the same modification**

Stock `password-auth` has the same `auth` section structure. Apply the identical insertion of the `with-pam-u2f-2fa` u2f line before `pam_unix`.

Read `cat /tmp/authselect-sssd/password-auth` and apply the same diff. Write to `system_files/etc/authselect/custom/blueberry/password-auth`.

- [ ] **Step 5: Write the README**

```
Blueberry custom authselect profile
====================================

Derived from Fedora's stock 'sssd' profile. Adds an opt-in pam_u2f line
gated by the 'with-pam-u2f-2fa' feature on system-auth and password-auth.

Activate with:
    authselect select custom/blueberry with-faillock with-pam-u2f-2fa with-fingerprint --force

The image build does this in build_files/45-authselect.sh.

Users without YubiKey-registered U2F credentials still log in normally —
pam_u2f is 'sufficient' and falls through to pam_unix on failure.
```

- [ ] **Step 6: Verify all six files present**

```bash
ls system_files/etc/authselect/custom/blueberry/
```
Expected: `README fingerprint-auth nsswitch.conf password-auth postlogin smartcard-auth system-auth`.

- [ ] **Step 7: Commit**

```bash
git add system_files/etc/authselect/custom/blueberry/
git commit -m "feat(pam): add custom authselect profile (sssd + pam_u2f cue, faillock)"
```

### Task G2: `/etc/pam.d/swaylock`

**Why:** Swaylock isn't part of authselect's templated set, so its PAM config is shipped directly. Spec §2 line 270 requires `pam_u2f cue=true` on swaylock specifically (so a YubiKey tap unlocks the screen).

**Files:**
- Create: `system_files/etc/pam.d/swaylock`

- [ ] **Step 1: Write file**

```
auth        required      pam_faillock.so preauth silent deny=4 unlock_time=1200
auth        sufficient    pam_u2f.so cue
auth        include       system-auth
auth        [default=die] pam_faillock.so authfail
account     required      pam_faillock.so
account     include       system-auth
```

(Falls through to `system-auth` for the `pam_unix` password path. The `pam_faillock` lines locally are needed because `include system-auth` doesn't carry through faillock's `auth required preauth` placement requirement.)

- [ ] **Step 2: Verify**

Run:
```bash
test -f system_files/etc/pam.d/swaylock
grep -q 'pam_u2f.so cue' system_files/etc/pam.d/swaylock
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add system_files/etc/pam.d/swaylock
git commit -m "feat(pam): add /etc/pam.d/swaylock with pam_u2f cue + faillock"
```

### Task G3: `build_files/45-authselect.sh`

**Why:** authselect needs to be told which profile is active. `authselect select` is idempotent and writes the PAM symlinks under `/etc/pam.d/` to point at the chosen profile. This must run at image build time so the booted system already has the desired PAM stack.

**Files:**
- Create: `build_files/45-authselect.sh`

- [ ] **Step 1: Write the build shard**

```bash
#!/usr/bin/bash
echo "::group:: ===$(basename "$0")==="
set -eoux pipefail

# Activate the custom authselect profile shipped under
# /etc/authselect/custom/blueberry/. authselect renders this profile's
# templates into /etc/pam.d/{system-auth,password-auth,...} and tracks
# the selection so future `authselect apply-changes` runs preserve it.
#
# --force is required because the base image already has a profile
# selected ('sssd' by default on Fedora atomic). The select operation
# is idempotent across rebuilds.
#
# Features enabled:
#   with-faillock        — wire pam_faillock into the auth phase
#   with-pam-u2f-2fa     — enable the pam_u2f line we added in
#                          system-auth/password-auth
#   with-fingerprint     — enable the stock pam_fprintd line; users
#                          opt in via `ujust enroll-fingerprint`

authselect select custom/blueberry \
    with-faillock with-pam-u2f-2fa with-fingerprint --force

echo "::endgroup::"
```

- [ ] **Step 2: Make executable and shellcheck**

Run:
```bash
chmod +x build_files/45-authselect.sh
shellcheck build_files/45-authselect.sh
```
Expected: exit 0, no warnings.

- [ ] **Step 3: Commit**

```bash
git add build_files/45-authselect.sh
git commit -m "feat(build): activate custom/blueberry authselect profile at image build"
```

### Task G4: Lane G build smoke test

- [ ] **Step 1: Build image**

Run: `just build`
Expected: success. The `45-authselect.sh` step runs `authselect select` and exits 0.

- [ ] **Step 2: Verify files + active profile inside image**

```bash
podman run --rm localhost/blueberry:latest sh -c '
  test -d /etc/authselect/custom/blueberry &&
  test -f /etc/pam.d/swaylock &&
  authselect current 2>&1 | grep -q "custom/blueberry" &&
  authselect current 2>&1 | grep -q "with-pam-u2f-2fa" &&
  echo OK
'
```
Expected: prints `OK`.

(If `authselect current` reports a different profile, the `--force` in `45-authselect.sh` was not effective — check build log for errors during the authselect step.)

- [ ] **Step 3: VM boot (manual gate)**

Optional: `just build-qcow2 && just run-vm-qcow2`. Verify a logged-in shell shows:
```
$ cat /etc/pam.d/system-auth
# Generated by authselect on ...
# (lines including pam_u2f.so cue and pam_faillock.so)
```

This step is a manual gate — flag if not green and let the user run it.

---

## Lane J — ISO sway disk config

Independent of E/F/G. Trivial.

### Task J1: `disk_config/iso-sway.toml`

**Why:** `bootc-image-builder` builds disk artifacts named after the toml file. The future `build-disk.yml` workflow (Lane K) fans out across `iso-{gnome,kde,sway}.toml`. Without `iso-sway.toml`, there's no sway-session ISO produced. Content is identical to `iso-gnome.toml` because the image's session is determined by greetd config, not by the disk-builder toml.

**Files:**
- Create: `disk_config/iso-sway.toml`

- [ ] **Step 1: Clone iso-gnome.toml**

```bash
cp disk_config/iso-gnome.toml disk_config/iso-sway.toml
```

- [ ] **Step 2: Verify identical content**

Run: `diff disk_config/iso-gnome.toml disk_config/iso-sway.toml`
Expected: no output (files identical).

- [ ] **Step 3: Commit**

```bash
git add disk_config/iso-sway.toml
git commit -m "feat(disk): add iso-sway.toml for sway-session ISO build"
```

---

## Self-review checklist (run after all lanes complete)

- [ ] Spec §3 `/etc/environment` materialized? — Lane E task 1
- [ ] Spec §3 kitty system config materialized? — Lane E task 2
- [ ] Spec §3 dconf defaults via gschema-overrides? — Lane E task 3
- [ ] Spec §5 system-wide MIME defaults? — Lane E task 4
- [ ] Spec §5 Firefox enterprise policies? — Lane F task 1
- [ ] Spec §5 Firefox flatpak override mounts /etc/firefox? — Lane F task 2
- [ ] Spec §2 PAM stack with pam_u2f cue + faillock + fingerprint? — Lane G tasks 1-3
- [ ] disk_config/iso-sway.toml exists? — Lane J task 1
- [ ] All commits clean (one logical change each, no `--no-verify`)?
- [ ] `just build` green at HEAD? — Lane F3 + Lane G4 smoke tests
- [ ] No accidental implementation of deferred lanes (H/I/K/L)?
