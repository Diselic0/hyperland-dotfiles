# Readme file for working with waybar.

1. Launch waybar manually:
  `waybar`
2. Launch waybar with debug/trace logging:
  `waybar -c ~/.config/waybar/config.jsonc -l trace` 
3. Validate JSON config:
  `jq . ~/.config/waybar/config.jsonc`
4. kill waybar:
  `pkill waybar` for safe killing
  `pkill -9 waybar` to force kill
5. Restart waybar via Hyprland (0.57+ takes Lua in `hyprctl dispatch`):
  `hyprctl dispatch 'hl.dsp.exec_cmd("pkill waybar; waybar")'`

