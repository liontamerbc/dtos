#!/bin/sh
# DTOS Qtile autostart (Dan wallpaper-persist fix v2)

SESSION_TYPE="x11"
[ "${XDG_SESSION_TYPE:-}" = "wayland" ] && SESSION_TYPE="wayland"
[ -n "$WAYLAND_DISPLAY" ] && SESSION_TYPE="wayland"

# Set keyboard layout explicitly (Qtile also has hook, but this is fine as backup)
[ "$SESSION_TYPE" = "x11" ] && setxkbmap gb &

# Start compositor if you use one (leave commented if another WM handles it)
# picom &

# Start network applet if installed
# nm-applet &

# Start any other tray apps you want
# volumeicon &
# Dunst notification daemon
dunst &

# Auto-reload Qtile when pywal colors change so widgets update without manual reloads
"$HOME/.config/qtile/wal-reloader.sh" &

### WALLPAPER RESTORE LOGIC ###
# We try, in order:
#  1. Qtile-specific cache (~/.cache/wall_qtile) if it exists and is non-empty
#  2. Generic DTOS cache   (~/.cache/wall)      if it exists and is non-empty
#  3. Fallback: random DTOS wallpaper so we never get a black screen

WALL_QTILE="$HOME/.cache/wall_qtile"
WALL_GENERIC="$HOME/.cache/wall"
WALL_DIR="/usr/share/backgrounds/dtos-backgrounds"
CHOSEN_WALL=""

set_wallpaper() {
    image_path="$1"
    [ -z "$image_path" ] && return 1

    if [ "$SESSION_TYPE" = "wayland" ]; then
        if command -v swaybg >/dev/null 2>&1; then
            # Replace any existing swaybg instance to avoid multiple daemons
            pkill -x swaybg 2>/dev/null || true
            swaybg -m fill -i "$image_path" &
            return 0
        elif command -v swww >/dev/null 2>&1; then
            # Start the swww daemon if it is not running yet
            pgrep -x swww-daemon >/dev/null 2>&1 || swww-daemon &
            swww img "$image_path" --transition-type simple --transition-fps 30 &
            return 0
        elif command -v qtile >/dev/null 2>&1; then
            # Fallback to Qtile's own wallpaper painter (Wayland-capable)
            qtile cmd-obj -o screen 0 -f set_wallpaper -a "['$image_path','fill']" >/dev/null 2>&1 || true
            qtile cmd-obj -o screen 1 -f set_wallpaper -a "['$image_path','fill']" >/dev/null 2>&1 || true
            return 0
        fi
        return 1
    fi

    # X11 wallpaper setter
    if command -v xwallpaper >/dev/null 2>&1; then
        xwallpaper --stretch "$image_path" &
    elif command -v feh >/dev/null 2>&1; then
        feh --no-fehbg --bg-scale "$image_path" &
    fi
}

choose_wallpaper() {
    target_file="$1"
    [ ! -s "$target_file" ] && return 1
    read -r image_path <"$target_file"
    CHOSEN_WALL="$image_path"
    set_wallpaper "$image_path"
}

if [ -s "$WALL_QTILE" ]; then
    # Non-empty Qtile-specific cache file – use it
    choose_wallpaper "$WALL_QTILE"
elif [ -s "$WALL_GENERIC" ]; then
    # Non-empty generic cache – use that
    choose_wallpaper "$WALL_GENERIC"
else
    # No valid cache, pick a random DTOS wallpaper
    if [ -d "$WALL_DIR" ]; then
        random_wall=$(find "$WALL_DIR" -type f | shuf -n 1)
        CHOSEN_WALL="$random_wall"
        set_wallpaper "$random_wall"
    fi
fi

# Re-apply pywal colors to match the chosen wallpaper (if pywal is installed)
if command -v wal >/dev/null 2>&1; then
    if [ -n "$CHOSEN_WALL" ] && [ -f "$CHOSEN_WALL" ]; then
        wal -n -q -i "$CHOSEN_WALL" >/dev/null 2>&1 || true
    elif [ -f "$HOME/.cache/wal/wal" ]; then
        wal -R -n -q >/dev/null 2>&1 || true
    fi
fi

# If you prefer nitrogen instead of xwallpaper, comment the whole block above
# and uncomment this:
# nitrogen --restore &

exit 0
