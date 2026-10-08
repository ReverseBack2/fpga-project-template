#!/bin/sh
set -eu
viewer=$1
wave=$2
layout=$3
command -v "$viewer" >/dev/null 2>&1 || { echo "GTKWave launcher not found: $viewer" >&2; exit 1; }
if [ -n "$layout" ] && [ -f "$layout" ]; then
    "$viewer" "$wave" "$layout" &
else
    "$viewer" "$wave" &
fi
