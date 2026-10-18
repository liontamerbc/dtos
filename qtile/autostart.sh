#!/bin/sh
# DTOS Qtile autostart (Dan wallpaper-persist fix v2)

# Set keyboard layout explicitly (Qtile also has hook, but this is fine as backup)
setxkbmap gb &

# Start compositor (picom config is installed by DTOS-Original)
picom --config "$HOME/.config/picom/picom.conf" &

# Start network applet if installed
# nm-applet &

# Start any other tray apps you want
# volumeicon &
# Dunst notification daemon
dunst &

### WALLPAPER RESTORE LOGIC ###
# We try, in order:
#  1. Qtile-specific cache (~/.cache/wall_qtile) if it exists and is non-empty
#  2. Generic DTOS cache   (~/.cache/wall)      if it exists and is non-empty
#  3. Fallback: random DTOS wallpaper so we never get a black screen

WALL_QTILE="$HOME/.cache/wall_qtile"
WALL_GENERIC="$HOME/.cache/wall"
WALL_DIR="/usr/share/backgrounds/dtos-backgrounds"

set_wall() {
    [ -z "$1" ] && return 1
    if command -v xwallpaper >/dev/null 2>&1; then
        xwallpaper --stretch "$1" &
    elif command -v feh >/dev/null 2>&1; then
        feh --no-fehbg --bg-scale "$1" &
    fi
}

if [ -s "$WALL_QTILE" ]; then
    # Non-empty Qtile-specific cache file – use it
    set_wall "$(head -n 1 "$WALL_QTILE")"
elif [ -s "$WALL_GENERIC" ]; then
    # Non-empty generic cache – use that
    set_wall "$(head -n 1 "$WALL_GENERIC")"
else
    # No valid cache, pick a random DTOS wallpaper
    if [ -d "$WALL_DIR" ]; then
        set_wall "$(find "$WALL_DIR" -type f | shuf -n 1)"
    fi
fi

# If you prefer nitrogen instead of xwallpaper, comment the whole block above
# and uncomment this:
# nitrogen --restore &

exit 0
