#!/usr/bin/env bash
TEMP_RAW=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null || echo 0)
USAGE=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0)
TEMP=$((TEMP_RAW / 1000))
echo "󰾲 ${USAGE}%  ${TEMP}°C"
