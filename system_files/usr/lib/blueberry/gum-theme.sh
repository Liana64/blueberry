# Source this file (`. /usr/lib/blueberry/gum-theme.sh`) in any script
# that uses `gum`. It exports the GUM_* environment variables that style
# every gum widget consistently with the rest of Blueberry's UI.

# Palette (matches groove.nix in the user's NixOS dotfiles)
export _BB_FG='#fbf1c7'        # foreground
export _BB_MUTED='#928374'     # comment / dim
export _BB_BG='#181818'        # darker
export _BB_ACCENT='#7daea3'    # blueberry blue
export _BB_OK='#a9b665'        # lime / success
export _BB_WARN='#e79a4e'      # orange
export _BB_ERR='#ea6962'       # red

# gum spin
export GUM_SPIN_SPINNER_FOREGROUND="$_BB_ACCENT"
export GUM_SPIN_TITLE_FOREGROUND="$_BB_FG"
export GUM_SPIN_SPINNER='dot'

# gum confirm
export GUM_CONFIRM_PROMPT_FOREGROUND="$_BB_FG"
export GUM_CONFIRM_SELECTED_BACKGROUND="$_BB_ACCENT"
export GUM_CONFIRM_SELECTED_FOREGROUND="$_BB_BG"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$_BB_MUTED"

# gum input
export GUM_INPUT_PROMPT_FOREGROUND="$_BB_ACCENT"
export GUM_INPUT_CURSOR_FOREGROUND="$_BB_ACCENT"

# gum choose
export GUM_CHOOSE_CURSOR_FOREGROUND="$_BB_ACCENT"
export GUM_CHOOSE_SELECTED_FOREGROUND="$_BB_OK"

# Helpers built on `gum style`
bb_header() {
    gum style \
        --foreground "$_BB_BG" --background "$_BB_ACCENT" \
        --bold --padding "0 2" --margin "1 0 0 0" \
        "blueberry  $*"
}

bb_ok() {
    gum style --foreground "$_BB_OK" --bold "✓ $*"
}

bb_warn() {
    gum style --foreground "$_BB_WARN" --bold "! $*"
}

bb_err() {
    gum style --foreground "$_BB_ERR" --bold "✗ $*"
}

bb_step() {
    gum style --foreground "$_BB_MUTED" "  → $*"
}
