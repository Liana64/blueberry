#!/usr/bin/env bash
# Poll boltctl; while a CalDigit TS4 is docked, hold a sleep inhibitor.
set -eu
while /usr/bin/boltctl list 2>/dev/null | grep -q "CalDigit"; do
    sleep 30
done
