# Ensure /usr/local/bin is on PATH (for pinned binary tools)
if ! echo "$PATH" | grep -q '/usr/local/bin'; then
    export PATH="/usr/local/bin:$PATH"
fi
