#!/usr/bin/bash
# Fail the build if any third-party / COPR repo is left enabled=1.
# COPRs that get installed via copr_install_isolated should be disabled
# again after the install completes; this catches drift.

echo "::group:: ===$(basename "$0")==="
set -eou pipefail

REPOS_DIR="/etc/yum.repos.d"
ENABLED=()

# Repo IDs (the [section] header inside the .repo file) that the base
# image (ublue-os/base-main) intentionally ships enabled.
ALLOWLIST_IDS=(
    "copr:copr.fedorainfracloud.org:ublue-os:akmods"
)

if [[ ! -d "$REPOS_DIR" ]]; then
    echo "::endgroup::"
    exit 0
fi

is_allowed_id() {
    local id="$1"
    for a in "${ALLOWLIST_IDS[@]}"; do
        [[ "$id" == "$a" ]] && return 0
    done
    return 1
}

# Scan every section of every .repo file. dnf-4 and dnf-5 differ in filename
# conventions but the [id] header is stable, so key the allowlist on that.
shopt -s nullglob
for f in "$REPOS_DIR"/*.repo; do
    [[ -r "$f" ]] || continue
    awk '
        /^\[.*\]/ { id = substr($0, 2, length($0) - 2); next }
        /^enabled[[:space:]]*=[[:space:]]*1/ { print id }
    ' "$f" | while read -r id; do
        # We want enabled IDs that are NOT base Fedora repos. Base Fedora
        # ids look like "fedora", "updates", "fedora-cisco-openh264" etc.
        # COPRs and third-party always have ":" or "_copr" or known names.
        case "$id" in
            fedora|fedora-debuginfo|fedora-source|\
            updates|updates-debuginfo|updates-source|\
            updates-testing|updates-testing-debuginfo|updates-testing-source|\
            fedora-cisco-openh264|google-chrome|rpmfusion-*)
                continue
                ;;
        esac
        if is_allowed_id "$id"; then
            echo "Allowed:  $id (in $(basename "$f"))"
        else
            echo "ENABLED:  $id (in $(basename "$f"))"
            ENABLED+=("$id")
        fi
    done
done

if [[ ${#ENABLED[@]} -gt 0 ]]; then
    echo "VALIDATION FAILED: the following repo IDs are still enabled:"
    for r in "${ENABLED[@]}"; do
        echo "  - $r"
    done
    exit 1
fi

echo "All third-party repos are disabled."
echo "::endgroup::"
