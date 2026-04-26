#!/usr/bin/bash
# Fail the build if any third-party / COPR repo is left enabled=1.
# COPRs that get installed via copr_install_isolated should be disabled
# again after the install completes; this catches drift.

echo "::group:: ===$(basename "$0")==="
set -eou pipefail

REPOS_DIR="/etc/yum.repos.d"
ENABLED=()

# Repos that are intentionally enabled by the base image (ublue-os/base-main)
# and should NOT trigger a validation failure.
ALLOWLIST=(
    _copr_ublue-os-akmods.repo
    _copr:copr.fedorainfracloud.org:ublue-os:akmods.repo
)

if [[ ! -d "$REPOS_DIR" ]]; then
    echo "::endgroup::"
    exit 0
fi

is_allowed() {
    local name="$1"
    for a in "${ALLOWLIST[@]}"; do
        [[ "$name" == "$a" ]] && return 0
    done
    return 1
}

check_file() {
    local f="$1"
    [[ -f "$f" && -r "$f" ]] || return 0
    local name
    name="$(basename "$f")"
    if grep -q "^enabled=1" "$f" 2>/dev/null; then
        if is_allowed "$name"; then
            echo "Allowed:  $name"
        else
            echo "ENABLED:  $name"
            ENABLED+=("$name")
        fi
    else
        echo "Disabled: $name"
    fi
}

# COPR repos (both standard and non-standard names)
for repo in "$REPOS_DIR"/_copr:copr.fedorainfracloud.org:*.repo "$REPOS_DIR"/_copr_*.repo; do
    [[ -f "$repo" ]] && check_file "$repo"
done

# Third-party repos we know we add
for repo_name in tailscale.repo; do
    [[ -f "$REPOS_DIR/$repo_name" ]] && check_file "$REPOS_DIR/$repo_name"
done

if [[ ${#ENABLED[@]} -gt 0 ]]; then
    echo "VALIDATION FAILED: the following repos are still enabled:"
    for r in "${ENABLED[@]}"; do
        echo "  - $r"
    done
    exit 1
fi

echo "All third-party repos are disabled."
echo "::endgroup::"
