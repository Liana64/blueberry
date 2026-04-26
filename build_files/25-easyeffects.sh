#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# Vendor cab404/framework-dsp at a pinned commit so EasyEffects can apply
# Gracefu's Edits preset on first login (firstboot/setup.sh symlinks the
# preset + IR into the EasyEffects flatpak sandbox).

FRAMEWORK_DSP_REF="6e5b8e7a5d1f422bcaa2f237f28223fe2292ca38"

dst=/etc/blueberry/easyeffects
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone --filter=blob:none --no-checkout \
    https://github.com/cab404/framework-dsp.git "$work"
git -C "$work" checkout "$FRAMEWORK_DSP_REF"

mkdir -p "$dst/irs"
install -m 0644 "$work/config/output/Gracefu's Edits.json" "$dst/cab-fw.json"
install -m 0644 "$work/config/irs/IR_22ms_27dB_5t_15s_0c.irs" \
    "$dst/irs/IR_22ms_27dB_5t_15s_0c.irs"

echo "::endgroup::"
