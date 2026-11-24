#!/usr/bin/env bash
# Called by matugen after it writes the [ii] spicetify color section.
# Puts that section into the active spicetify theme's color.ini (any other
# sections, like the theme's own, stay as they are). Spotify is only touched when
# color_scheme is set to "ii":  spicetify config color_scheme ii && spicetify apply
set -euo pipefail
command -v spicetify >/dev/null || exit 0
src="$1"
cfg="$(spicetify -c 2>/dev/null)" || exit 0
[ -f "$cfg" ] || exit 0
theme="$(sed -nE 's/^current_theme[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' "$cfg")"
scheme="$(sed -nE 's/^color_scheme[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' "$cfg")"
[ -n "$theme" ] || exit 0
dir="$(dirname "$cfg")/Themes/$theme"
[ -d "$dir" ] || exit 0
ini="$dir/color.ini"
tmp="$(mktemp "$dir/.color.ini.XXXXXX")"
# drop the old [ii] section, keep everything else, then append the new one
if [ -f "$ini" ]; then
    awk '/^\[/{skip=($0=="[ii]")} !skip' "$ini" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$tmp"
    printf '\n' >> "$tmp"
fi
cat "$src" >> "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$ini"
if [ "$scheme" = "ii" ]; then
    spicetify -q -n refresh -s || true
fi
