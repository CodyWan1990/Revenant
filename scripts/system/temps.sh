#!/usr/bin/env bash
# Every hwmon temperature sensor as JSON, for services/Temps.qml:
#   [{"id","chip","dev","label","c"}, ...]
# `id` is chip@device:label — stable across boots (hwmonN numbers are not,
# and two GPUs both call themselves "amdgpu"). `c` is whole °C.
set -uo pipefail

first=1
printf '['
for h in /sys/class/hwmon/hwmon*; do
    [[ -r $h/name ]] || continue
    chip=$(<"$h/name")
    dev=$(basename "$(readlink -f "$h/device" 2>/dev/null)" 2>/dev/null)
    [[ -n $dev && $dev != device ]] || dev=$(basename "$h")
    for input in "$h"/temp*_input; do
        [[ -r $input ]] || continue
        raw=$(cat "$input" 2>/dev/null) || continue
        [[ $raw =~ ^-?[0-9]+$ ]] || continue
        base=${input%_input}
        if [[ -r ${base}_label ]]; then label=$(<"${base}_label"); else label=${base##*/}; fi
        label=${label//\"/}
        (( first )) || printf ','
        first=0
        printf '{"id":"%s@%s:%s","chip":"%s","dev":"%s","label":"%s","c":%d}' \
            "$chip" "$dev" "$label" "$chip" "$dev" "$label" $(( raw / 1000 ))
    done
done
printf ']\n'
