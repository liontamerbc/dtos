#!/bin/sh
# DTOS Qtile autostart (Dan wallpaper-persist fix v2)

# Clear leftover Wayland variables from previous Hyprland session so OpenRGB doesn't crash-loop the Wooting USB interface
systemctl --user unset-environment WAYLAND_DISPLAY XDG_BACKEND MOZ_ENABLE_WAYLAND 2>/dev/null || true
systemctl --user import-environment DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP 2>/dev/null || true
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP 2>/dev/null || true
setxkbmap gb

# Enable AMDGPU TearFree and 180Hz on both monitors to eliminate screen tearing
[ "${XDG_SESSION_TYPE:-x11}" != "wayland" ] && xrandr --output DisplayPort-0 --mode 1920x1080 --rate 180.00 --set TearFree on --output DisplayPort-1 --mode 1920x1080 --rate 180.00 --right-of DisplayPort-0 --set TearFree on &

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
CHOSEN_WALL=""

set_wall() {
    [ -z "$1" ] && return 1
    CHOSEN_WALL="$1"
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

# Generate pywal cache for RGB sync even in dtos-original
if command -v wal >/dev/null 2>&1 && [ -n "$CHOSEN_WALL" ] && [ -f "$CHOSEN_WALL" ]; then
    wal -n -q -i "$CHOSEN_WALL" -o "$HOME/.config/wal/postrun" >/dev/null 2>&1 || true
fi

# If you prefer nitrogen instead of xwallpaper, comment the whole block above
# and uncomment this:
# nitrogen --restore &

exit 0
