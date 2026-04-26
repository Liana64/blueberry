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
