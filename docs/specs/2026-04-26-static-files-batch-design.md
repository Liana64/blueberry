# Blueberry Static-Files Batch — Design

- **Status:** Draft
- **Date:** 2026-04-26
- **Author:** Liana64
- **Scope:** Lanes E, F, G, J of the deferred items from `2026-04-26-spec-gap-fill.md`
- **Parent spec:** `docs/specs/2026-04-25-blueberry-design.md`

## Summary

Closes four of the eight deferred lanes from the spec-gap-fill plan, all of
which materialize as static files under `system_files/` or `disk_config/`,
copied verbatim by the Containerfile. One build-step edit
(`build_files/50-hardening.sh`) is needed in Lane G to activate the custom
authselect profile. No new services, no new logic.

The four lanes are path-disjoint and can be implemented by parallel agents
without coordination.

## Goals

1. Ship `/etc/environment`, kitty system config, dconf defaults, and
   system-wide MIME defaults so the sway session has a consistent
   environment without per-user setup (Lane E).
2. Ship Firefox enterprise policies covering telemetry, tracking
   protection, HTTPS-only, search engines, and required extensions
   (Lane F).
3. Ship a custom authselect profile that wires `pam_u2f cue=true`,
   `pam_faillock`, fingerprint, and gnome-keyring into the standard
   PAM stack, plus a `swaylock` PAM file (Lane G).
4. Ship `disk_config/iso-sway.toml` so the sway-session ISO artifact has
   a name `build-disk.yml` (future, Lane K) can fan out on (Lane J).

## Non-goals

- Lanes H (waybar/MOTD/audit helpers), I (Brewfile + user firstboot),
  K (GHA workflows), and L (install/MIGRATION docs) — each gets its own
  design doc.
- Updating the parent spec's §2 prose to match the chosen minimalist
  audit baseline — filed as a doc-fix follow-up.
- Per-user kitty/firefox tweaks (font size, profile-level prefs) — those
  remain chezmoi territory, layered on top of the image defaults.

## Decisions made

| Decision | Choice | Rationale |
|---|---|---|
| Audit baseline | Keep current minimalist (anomaly-only, no watches) | Conflicts with spec §2 — current state is canonical, spec gets a doc-fix |
| auditd.conf sizing | Keep current `max_log_file=50, num_logs=5` | Same — current state canonical |
| `faillock.conf` lockout | Keep current `unlock_time=900` | Same |
| PAM strategy | Custom authselect profile | Works with the platform; survives `authselect apply-changes` |
| Kitty config | Image-owned at `/etc/xdg/kitty/kitty.conf` | Ships a working kitty out of the box; user can override via chezmoi |
| Firefox policies | Full image-owned port of `firefox.nix` | Search engines + extension list are part of the curated UX, not per-user prefs |
| MIME defaults path | `/usr/share/applications/mimeapps.list` | Distribution-defaults path, consumed by xdg-open without user mutation |
| dconf defaults path | `/usr/share/glib-2.0/schemas/99-blueberry.gschema.override` | gschema-override approach per spec §3 |

## Lane E — Desktop polish

Four files. No build-step changes. `glib-compile-schemas` runs automatically
during RPM install for any package shipping under
`/usr/share/glib-2.0/schemas/`, so the override is picked up without
explicit invocation.

### Files

- `system_files/etc/environment`

  Direct port of spec §3 lines 492–508. Contents:

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

- `system_files/etc/xdg/kitty/kitty.conf`

  Verbatim port of `~/.dotfiles/home/common/kitty.nix` (~127 LoC of Nix
  expressing kitty config). Settings include: Dracula palette,
  JetBrainsMono Nerd Font (Cascadia Mono NF fallback for parity with
  Lane B's waybar/mako/rofi font note), beam cursor, scrollback 200000,
  full keybind set, 7-tab `startup.session` (home/dev/ai/mon/ctl/rmt/
  perf). Implementer reads `kitty.nix` first and produces a `.conf` of
  equivalent shape.

- `system_files/usr/share/glib-2.0/schemas/99-blueberry.gschema.override`

  Port of `~/.dotfiles/home/linux/dconf.nix` (17 LoC). Sets:

  ```
  [org.gtk.Settings.FileChooser]
  show-hidden=true
  sort-directories-first=true

  [org.gnome.desktop.interface]
  color-scheme='prefer-dark'
  ```

  (plus any additional dconf settings in `dconf.nix`; implementer reads
  it first.)

- `system_files/usr/share/applications/mimeapps.list`

  System-wide MIME defaults. Format:

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

  (Firefox is a Flatpak — the `.desktop` file lands at
  `/var/lib/flatpak/exports/share/applications/org.mozilla.firefox.desktop`,
  which is in `XDG_DATA_DIRS` for any logged-in user. The mimeapps
  binding works against the desktop-id, not the path.)

## Lane F — Firefox policies

One file. No build-step changes.

### Files

- `system_files/etc/firefox/policies/policies.json`

  Mozilla enterprise-policies-schema JSON port of
  `~/.dotfiles/home/linux/firefox.nix` (291 LoC of Nix). The Nix file
  uses `firefox.policies` as a flat attrset that maps almost 1:1 onto
  the JSON schema; the only reshaping needed is wrapping the result in
  `{"policies": {...}}` and converting Nix booleans/lists to JSON.

  Required policy keys (subagent reads `firefox.nix` for full list and
  exact values):

  - **Telemetry off:** `DisableTelemetry`, plus the `Preferences` block
    that pins all `toolkit.telemetry.*` and `datareporting.*` to false.
  - **Disabled features:** `DisableFirefoxStudies`, `DisablePocket`,
    `DisableAccounts`, `DisableFirefoxAccounts`,
    `DontCheckDefaultBrowser`, `OverrideFirstRunPage = ""`,
    `OverridePostUpdatePage = ""`.
  - **Privacy:** `EnableTrackingProtection.Value=true,Locked=true`,
    `HttpsOnlyMode = "enabled"`.
  - **Branding:** `Homepage.URL = "https://labs.lianas.org"`,
    `Homepage.StartPage = "homepage"`.
  - **Search:** `SearchEngines.Default = "Kagi"`. `SearchEngines.Add`
    list: Kagi, GitHub, Flathub, Kubesearch, Nixpkgs, Nix Options,
    OpenSecrets (URL/Method/IconURL per `firefox.nix`).
    `SearchEngines.Remove = ["Bing"]`.
  - **GPU/VAAPI:** `Preferences` block setting
    `gfx.webrender.all=true`, `media.ffmpeg.vaapi.enabled=true`,
    `widget.dmabuf.force-enabled=true`.
  - **Extensions:** `ExtensionSettings` with
    `"{3c078156-979c-498b-8990-85f7987dd929}"` (Sidebery) and
    `uBlock0@raymondhill.net` (uBlock Origin) → install_url + force.

### Flatpak override prerequisite

The Firefox Flatpak needs `--filesystem=/etc/firefox:ro` in
`/etc/flatpak/overrides/org.mozilla.firefox` for the Flatpak to actually
read the system policies. Spec §5 lists this override; implementer
verifies the file exists and adds the line if missing.

## Lane G — PAM via custom authselect profile

Five-to-seven files plus one build-step edit.

### Strategy

Fedora atomic manages `/etc/pam.d/` via `authselect`. Hand-editing those
files gets clobbered the next time `authselect apply-changes` runs.
Instead: ship a custom profile under
`/etc/authselect/custom/blueberry/`, then in `50-hardening.sh` switch to
it with the desired feature flags.

### Files

- `system_files/etc/authselect/custom/blueberry/{system-auth,password-auth,fingerprint-auth,smartcard-auth,postlogin,nsswitch.conf}`

  Clone of Fedora's stock `/usr/share/authselect/default/sssd/` profile.
  The only modification is in `system-auth` and `password-auth`: insert
  `auth sufficient pam_u2f.so cue` (gated by the `with-pam-u2f-2fa`
  feature so users without YubiKey enrolled still log in) before
  `pam_unix`, and `auth required pam_faillock.so preauth` /
  `pam_faillock.so authfail` around it.

  pam_gnome_keyring lines come from the stock profile — no edit needed.

  Implementer copies the active Fedora profile from a running container
  build:

  ```bash
  podman run --rm fedora:latest cat /usr/share/authselect/default/sssd/system-auth
  ```

  and applies the diff above.

- `system_files/etc/authselect/custom/blueberry/README`

  One-paragraph description of what this profile is and what features
  it expects (`with-faillock with-pam-u2f-2fa with-fingerprint`).

- `system_files/etc/pam.d/swaylock`

  Direct file (swaylock isn't part of authselect's templated set):

  ```
  auth        required      pam_faillock.so preauth
  auth        sufficient    pam_u2f.so cue
  auth        include       system-auth
  auth        [default=die] pam_faillock.so authfail
  account     required      pam_faillock.so
  account     include       system-auth
  ```

### Build-step edit

- `build_files/50-hardening.sh` — append:

  ```bash
  authselect select custom/blueberry with-faillock with-pam-u2f-2fa with-fingerprint --force
  ```

  `--force` is required because the base image typically already has a
  profile selected. The select operation is idempotent.

### What the profile does NOT change

- `pam_pwquality` (password complexity) — left at Fedora defaults.
- `nsswitch.conf` is shipped because authselect requires it in the
  profile; content matches the stock `sssd` profile.

## Lane J — ISO sway disk config

One file. No build-step changes.

### Files

- `disk_config/iso-sway.toml`

  Clone of `disk_config/iso-gnome.toml` (whose content is currently
  identical to `iso-kde.toml` — they only differ by file name). Used by
  `bootc-image-builder` to build a sway-session ISO. The file name is
  what the future `build-disk.yml` workflow (Lane K) will fan out on.

  Content:

  ```toml
  [customizations.installer.kickstart]
  contents = """
  %post
  bootc switch --mutate-in-place --transport registry ghcr.io/liana64/blueberry:latest
  %end
  """

  [customizations.installer.modules]
  enable = [
    "org.fedoraproject.Anaconda.Modules.Storage",
    "org.fedoraproject.Anaconda.Modules.Runtime"
  ]
  disable = [
    "org.fedoraproject.Anaconda.Modules.Network",
    "org.fedoraproject.Anaconda.Modules.Security",
    "org.fedoraproject.Anaconda.Modules.Services",
    "org.fedoraproject.Anaconda.Modules.Users",
    "org.fedoraproject.Anaconda.Modules.Subscription",
    "org.fedoraproject.Anaconda.Modules.Timezone"
  ]
  ```

## Testing

Per-lane verification is file-presence + lint, matching gap-fill style:

- `shellcheck build_files/50-hardening.sh` after Lane G's edit.
- `just build` — must pass `bootc container lint`.
- `podman run --rm localhost/blueberry:latest ls <files>` per lane.
- Manual VM gate (Lane G only): boot qcow2, verify `authselect current`
  reports `custom/blueberry with-faillock with-pam-u2f-2fa
  with-fingerprint`, and that `cat /etc/pam.d/system-auth` reflects the
  custom profile's content.

## Parallel-dispatch shape

| Lane | Files touched | Commits | Agent count |
|---|---|---|---|
| E | 4 (all new) | 1 per file = 4 | 1 |
| F | 1 (new) + 1 (override edit if missing) | 1–2 | 1 |
| G | 7 (new) + 1 (`50-hardening.sh` edit) | 1 | 1 |
| J | 1 (new) | 1 | 1 |

All four agents safe to run in parallel. No shared files.

## Acceptance

- All listed files present in built image.
- `bootc container lint` clean.
- `authselect current` reports the custom profile.
- Booted VM honors Firefox policies (visible in `about:policies`).
- Booted VM honors `/etc/environment` (visible in any login shell's
  environment).
- `xdg-mime query default text/html` returns
  `org.mozilla.firefox.desktop`.

## Follow-ups

- Doc-fix to spec §2 audit/faillock prose to match minimalist baseline
  the image actually ships.
- Verify and add `--filesystem=/etc/firefox:ro` to Firefox flatpak
  override if missing (Lane F sub-task).
- Lanes H/I/K/L specs.
