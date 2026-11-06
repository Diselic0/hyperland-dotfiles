#!/usr/bin/env bash
# Waybar custom/gpu module (return-type: json)
#   Bar text: discrete GPU load + GPU edge temperature
#   Tooltip:  the most relevant system temperatures, with names and limits
#
# Sensors are looked up by driver name and label on every run, because the
# hwmonN / cardN numbers are not guaranteed to stay the same between boots.
#
# Sensors on this machine (see `sensors`):
#   k10temp      Ryzen 7 9800X3D: Tctl (control temp), Tccd1 (core die). TjMax 95 °C
#   amdgpu       RX 9070 (the one with a "junction" label): edge, junction, mem, fan1
#   amdgpu       Radeon 610M iGPU (inside the CPU) - skipped, duplicates the CPU
#   nvme         Samsung 990 PRO: Composite (warning 82 °C, critical 85 °C)
#   spd5118 x2   DDR5 sticks (high 55 °C, critical 85 °C)
#   prom21_xhci  AMD 800-series chipset
#   r8169, mt7921  Ethernet / Wi-Fi chips - skipped, rarely relevant
export LC_ALL=C

C_HEAD='#76c893'   # section headers (palette accent)
C_WARM='#f4d35e'   # warm
C_HOT='#ff6b6b'    # close to the limit

# hwmon dirs whose driver name is $1
hwmons() {
    local h
    for h in /sys/class/hwmon/hwmon*; do
        [[ $(<"$h/name") == "$1" ]] && echo "$h"
    done
}

# millidegrees from hwmon dir $1: the temp*_input labelled $2, or temp1 if no label given
temp_of() {
    local h=$1 label=$2 f
    [[ -z $h ]] && return
    if [[ -z $label ]]; then cat "$h/temp1_input" 2>/dev/null; return; fi
    for f in "$h"/temp*_label; do
        if [[ -e $f && $(<"$f") == "$label" ]]; then cat "${f%_label}_input" 2>/dev/null; return; fi
    done
}

# escape text for Pango markup
esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; echo "${s//>/&gt;}"; }

TIP=""
section() { TIP+="${TIP:+$'\n'}<span foreground='$C_HEAD'><b>$(esc "$1")</b></span>"; }

# row <name> <millidegrees> <warm-at> <hot-at> [limit]
row() {
    local name=$1 m=$2 warm=$3 hot=$4 limit=$5 t val
    [[ $m =~ ^-?[0-9]+$ ]] || return
    t=$(( (m + 500) / 1000 ))
    val=$(printf '%3d°C' "$t")
    if   (( t >= hot  )); then val="<span foreground='$C_HOT'><b>$val</b></span>"
    elif (( t >= warm )); then val="<span foreground='$C_WARM'>$val</span>"
    fi
    TIP+=$'\n'"$(printf '  %-19s' "$name") $val"
    [[ -n $limit ]] && TIP+="    <span alpha='55%'>$(printf '%3d°C' "$limit")</span>"
}

# --- locate sensors ---------------------------------------------------------
CPU=$(hwmons k10temp | head -n1)
DGPU=""
for h in $(hwmons amdgpu); do
    grep -qx junction "$h"/temp*_label 2>/dev/null && DGPU=$h   # iGPU has no junction sensor
done
NVME=$(hwmons nvme | head -n1)
CHIPSET=$(hwmons prom21_xhci | head -n1)
mapfile -t DIMMS < <(hwmons spd5118)

# --- bar text (unchanged look: load + edge temp) ----------------------------
USAGE=$(cat "$DGPU/device/gpu_busy_percent" 2>/dev/null || echo 0)
EDGE=$(temp_of "$DGPU" edge)
TEXT="󰾲 ${USAGE}%  $(( (${EDGE:-0} + 500) / 1000 ))°C"

# --- tooltip ----------------------------------------------------------------
TIP="<span alpha='55%'>  Sensor               Now     Limit</span>"

CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | sed -e 's/.*: //' -e 's/^AMD //' -e 's/ [0-9]*-Core Processor//')
section "CPU · ${CPU_MODEL:-CPU}"
row "CPU (Tctl)"         "$(temp_of "$CPU" Tctl)"      80  90  95
row "Core die (CCD1)"    "$(temp_of "$CPU" Tccd1)"     80  90  95

section "GPU · Radeon RX 9070 series"
row "Hotspot (junction)" "$(temp_of "$DGPU" junction)" 90 100 110
row "Edge"               "$(temp_of "$DGPU" edge)"     80  95 110
row "VRAM"               "$(temp_of "$DGPU" mem)"      90 100 108
FAN=$(cat "$DGPU/fan1_input" 2>/dev/null)
if [[ $FAN =~ ^[0-9]+$ ]]; then
    TIP+=$'\n'"$(printf '  %-19s %4d RPM' "Fan" "$FAN")"
    (( FAN == 0 )) && TIP+="  <span alpha='55%'>(stopped: idle)</span>"
fi

NVME_MODEL=$(sed -e 's/[[:space:]]*$//' -e 's/^Samsung SSD //' /sys/class/nvme/nvme0/model 2>/dev/null)
section "Storage"
row "NVMe ${NVME_MODEL:-SSD}" "$(temp_of "$NVME" Composite)" 70 80 82

section "Memory (DDR5)"
for i in "${!DIMMS[@]}"; do
    row "RAM stick $((i + 1))" "$(temp_of "${DIMMS[$i]}")" 55 75 85
done

section "Motherboard"
row "Chipset"            "$(temp_of "$CHIPSET")"       75  85

TIP+=$'\n'"<span alpha='55%'>yellow = warm · red = close to the limit</span>"

jq -cn --arg text "$TEXT" --arg tooltip "$TIP" '{text: $text, tooltip: $tooltip}'
