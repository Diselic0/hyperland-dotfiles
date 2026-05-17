#!/usr/bin/env bash
# Show a wofi dmenu of all open windows and focus the selected one.
JSON=$(hyprctl clients -j)
LIST=$(echo "$JSON" | jq -r '.[] | "\(.workspace.name): \(.class) — \(.title)"')
[ -z "$LIST" ] && exit 0

SELECTED=$(printf '%s\n' "$LIST" | wofi --dmenu --prompt "  Focus window" --insensitive)
[ -z "$SELECTED" ] && exit 0

# Match selected line → get address by line index (handles duplicate titles)
LINENO=$(printf '%s\n' "$LIST" | grep -Fn "$SELECTED" | head -1 | cut -d: -f1)
ADDRESS=$(echo "$JSON" | jq -r ".[$((LINENO - 1))].address")
hyprctl dispatch focuswindow "address:$ADDRESS"
