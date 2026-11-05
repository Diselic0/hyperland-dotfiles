#!/usr/bin/env bash
# Show a wofi dmenu of all open windows and focus the selected one.
JSON=$(hyprctl clients -j)
LIST=$(echo "$JSON" | jq -r '.[] | "\(.workspace.name): \(.class) — \(.title)"')
[ -z "$LIST" ] && exit 0

SELECTED=$(printf '%s\n' "$LIST" | wofi --dmenu --prompt "  Focus window" --insensitive)
[ -z "$SELECTED" ] && exit 0

# Match selected line → get address by line index.
# (Don't name this LINENO: that's a bash built-in that resets on every line.)
IDX=$(printf '%s\n' "$LIST" | grep -Fxn -- "$SELECTED" | head -1 | cut -d: -f1)
[ -z "$IDX" ] && exit 1
ADDRESS=$(echo "$JSON" | jq -r ".[$((IDX - 1))].address")

# Hyprland 0.57+: hyprctl dispatch takes Lua.
hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDRESS\" })"
