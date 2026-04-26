#!/usr/bin/bash
set -eoux pipefail

# Run each numbered build shard in order. Each shard wraps its work in
# `::group::` markers so the GitHub Actions log stays readable.
for script in /ctx/[0-9]*.sh; do
    "$script"
done

# Final guard: make sure no third-party / COPR repo is left enabled.
/ctx/validate-repos.sh
