#!/usr/bin/env bash
# Watch the pywal cache and reload Qtile when it changes so widgets update colors.
set -euo pipefail

cache="$HOME/.cache/wal/colors.json"
last_mtime=""

get_mtime() {
    # Linux: stat -c; BSD/macOS fallback: stat -f
    stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache"
}

while :; do
    if [ -f "$cache" ]; then
        mtime=$(get_mtime 2>/dev/null || true)
        if [ -n "${mtime:-}" ] && [ "$mtime" != "$last_mtime" ]; then
            last_mtime="$mtime"
            qtile cmd-obj -o cmd -f fire_user_hook -a recolor_bar >/dev/null 2>&1 || true
        fi
    fi
    sleep 2
done
