#!/usr/bin/env bash

# Script name: _dm-helper
# Description: A helper script for the other scripts in the collection.
# Dependencies:
# GitLab: https://www.gitlab.com/dwt1/dmscripts
# License: https://www.gitlab.com/dwt1/dmscripts/LICENSE
# Contributors: Simon Ingelsson
#               HostGrady
#               aryak1

set -euo pipefail

# Hard block: if DM_BLOCK is set, bail immediately so stray auto-launches do nothing.
[ -n "${DM_BLOCK:-}" ] && exit 0

# Log invocations to help trace unwanted auto-launches (e.g., dm-wifi popping up)
{
    script_name="$(basename "${0:-unknown}")"
    parent_cmd=$(ps -o comm= -p "${PPID:-0}" 2>/dev/null || echo "unknown")
    parent_line=$(ps -o pid=,ppid=,cmd= -p "${PPID:-0}" 2>/dev/null | tr -s ' ')
    grandpid=$(ps -o ppid= -p "${PPID:-0}" 2>/dev/null | tr -d ' ' || echo "")
    grand_line=
    if [ -n "$grandpid" ]; then
        grand_line=$(ps -o pid=,ppid=,cmd= -p "$grandpid" 2>/dev/null | tr -s ' ')
    fi
    tree=$(pstree -pal "${PPID:-0}" 2>/dev/null | head -n 1)
    printf '%s script=%s ppid=%s parent=%s args="%s" pstree=%s parent_line=\"%s\" grand_line=\"%s\"\n' \
        "$(date '+%F %T')" "$script_name" "${PPID:-?}" "$parent_cmd" "$*" "$tree" "$parent_line" "$grand_line" \
        >>/tmp/dmscripts.trace
} || true

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

######################
#   Error handling   #
######################

# Simple warn function
warn() {
    printf 'Warn: %s\n' "$1"
}

# Simple error function
err() {
    printf 'Error: %s\n' "$1"
    exit 1
}

############################
#   Dislay server checks   #
############################

# Boiler code for if you want to do something with display servers

# Simple check for an available display (X11 or Wayland)
display_available() {
    [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

# Use the current pywal palette for dmenu if available.
apply_pywal_menu_colors() {
    # Allow opting out by setting DMENU_PYWAL=0.
    if [ "${DMENU_PYWAL:-1}" != "1" ]; then
        return
    fi

    # Avoid touching non-dmenu launchers.
    if [ -z "${DMENU:-}" ] || [[ "${DMENU}" != *dmenu* ]]; then
        return
    fi

    local wal_colors="$HOME/.cache/wal/colors.sh"
    [ -f "$wal_colors" ] || return

    : "${FZF_DEFAULT_OPTS:=}" "${LS_COLORS:=}"
    # shellcheck disable=SC1090
    . "$wal_colors"

    local bg="${background:-${color0:-}}"
    local fg="${foreground:-${color7:-}}"
    local accent="${color4:-${color2:-${color1:-}}}"
    local sel_fg="${color15:-${fg}}"

    # Require the basics so we don't emit an incomplete command.
    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        return
    fi

    # Rebuild the DMENU command so -p stays at the end and wal colors land before it.
    local prompt_flag="-p"
    local parts=()
    read -r -a parts <<<"${DMENU}"

    local rebuilt=()
    for part in "${parts[@]}"; do
        if [ "$part" = "-p" ] || [ "$part" = "--prompt" ]; then
            prompt_flag="$part"
            break
        fi
        rebuilt+=("$part")
    done

    # Build without extra quoting so colors pass cleanly to dmenu/rofi.
    DMENU="${rebuilt[*]} -nb ${bg} -nf ${fg} -sb ${accent} -sf ${sel_fg} ${prompt_flag}"
}

#function() {
#  case "$XDG_SESSION_TYPE" in
#    'x11') something with x;;
#    'wayland') something with wayland;;
#    *) err "Unknown display server";;
#  esac
#}

# Function to copy to clipboard with different tools depending on the display server
cp2cb() {
    case "$XDG_SESSION_TYPE" in
    'x11') xclip -r -selection clipboard ;;
    'wayland') wl-copy -n ;;
    *) err "Unknown display server" ;;
    esac
}

grep-desktop() {
    case "$XDG_SESSION_TYPE" in
    'x11') grep "Name=" /usr/share/xsessions/*.desktop | cut -d'=' -f2 ;;
    'wayland') grep "Name=" /usr/share/wayland-sessions/*.desktop | cut -d'=' -f2 || grep "Name=" /usr/share/xsessions/*.desktop | grep -i "wayland" | cut -d'=' -f2 | cut -d' ' -f1 ;;
    *) err "Unknown display server" ;;
    esac
}

###############
#   Parsing   #
###############

# simple function which provides a key-value pair in the form of the DM_XML_TAG and DM_XML_VALUE varaibles
xmlgetnext() {
    local IFS='>'
    # we need to mangle backslashes for this to work (SC2162)
    # The DM_XML_* variables are global variables and are expected to be read and dealt with by someone else (SC2034)
    # shellcheck disable=SC2162,SC2034
    read -d '<' DM_XML_TAG DM_XML_VALUE
}

#################
# Help Function #
#################

# Every script has a '-h' option that displays the following information.
help() {
    printf '%s%s%s\n' "Usage: $(basename "$0") [options]
$(grep '^# Description: ' "$0" | sed 's/# Description: /Description: /g')
$(grep '^# Dependencies: ' "$0" | sed 's/# Dependencies: /Dependencies: /g')

The folowing OPTIONS are accepted:
    -h  displays this help page
    -d  runs the script using 'dmenu'
    -f  runs the script using 'fzf'
    -r  runs the script using 'rofi'

Running" " $(basename "$0") " "without any argument defaults to using 'dmenu'
Run 'man dmscripts' for more information" >/dev/stderr
}

####################
# Handle Arguments #
####################

# this function is a simple parser designed to get the menu program and then exit prematurally
get_menu_program() {
    # If script is run with '-d', it will use 'dmenu'
    # If script is run with '-f', it will use 'fzf'
    # If script is run with '-r', it will use 'rofi'
    while getopts "dfrh" arg 2>/dev/null; do
        case "${arg}" in
        d) # shellcheck disable=SC2153
            echo "${DMENU}"
            return 0
            ;;
        f) # shellcheck disable=SC2153
            echo "${FMENU}"
            return 0
            ;;
        r) # shellcheck disable=SC2153
            echo "${RMENU}"
            return 0
            ;;
        h)
            help
            return 1
            ;;
        *)
            echo "invalid option:
Type $(basename "$0") -h for help" >/dev/stderr
            return 1
            ;;
        esac
    done
    echo "Did not find menu argument, using \${DMENU}" >/dev/stderr
    # shellcheck disable=SC2153
    echo "${DMENU}"
}

####################
# Boilerplate Code #
####################

# this function will source the dmscripts config files in the order specified below:
#
# Config priority (in order of which code takes precendent over the other):
# 1. Git repository config - For developers
# 2. $XDG_CONFIG_HOME/dmscripts/config || $HOME/.config/dmscripts/config - For local edits
# 3. /etc/dmscripts/config - For the gloabl/default configuration
#
# Only 1 file is ever sourced

# this warning is simply not necessary anywhere in the scope
# shellcheck disable=SC1091
source_dmscripts_configs() {
    # this is to ensure this variable is defined
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-}"

    if [ -f "../config/config" ]; then
        source "../config/config"
        apply_pywal_menu_colors
        return 0
    fi

    if [ -z "$XDG_CONFIG_HOME" ] && [ -f "$HOME/.config/dmscripts/config" ]; then
        source "$HOME/.config/dmscripts/config"
        apply_pywal_menu_colors
        return 0
    fi

    if [ -n "$XDG_CONFIG_HOME" ] && [ -f "$XDG_CONFIG_HOME/dmscripts/config" ]; then
        source "$XDG_CONFIG_HOME/dmscripts/config"
        apply_pywal_menu_colors
        return 0
    fi

    [ -f "/etc/dmscripts/config" ] && source "/etc/dmscripts/config"
    apply_pywal_menu_colors
}

# checks the base configuration file and compares it with the local configuration file
# if the numbers are different then the code will return 0, else 1
#
# this does not check the git config as it doesn't make sense
configs_are_different() {
    local _base_file=""
    local _config_file=""

    # DM_SHUTUP is a variable in the dmscript config that is intended to silence the notifications.
    DM_SHUTUP="${DM_SHUTUP:-}"

    # it cannot determine if the files are different if it does not exist
    [ -f "/etc/dmscripts/config" ] && _base_file="/etc/dmscripts/config" || return 1

    # this is essentially the same idea as seen previous just with different variable names
    local _xdg_config_home="${XDG_CONFIG_HOME:-}"

    [ -z "$_xdg_config_home" ] && [ -f "$HOME/.config/dmscripts/config" ] && _config_file="$HOME/.config/dmscripts/config"
    [ -n "$_xdg_config_home" ] && [ -f "$XDG_CONFIG_HOME/dmscripts/config" ] && _config_file="$XDG_CONFIG_HOME/dmscripts/config"

    # if there is no other config files then just exit.
    [ -z "$_config_file" ] && return 1

    _config_file_revision=$(grep "^_revision=" "${_config_file}")
    _base_file_revision=$(grep "^_revision=" "${_base_file}")

    if [[ ! "${_config_file_revision}" == "${_base_file_revision}" ]]; then
        if [ -z "$DM_SHUTUP" ]; then
            notify-send "dmscripts configuration outdated" "Review the differences of /etc/dmscripts/config and your local config and apply changes accordingly (dont forget to bump the revision number)"
        fi
        return 0
    fi

    return 1
}
