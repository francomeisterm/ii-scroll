#!/usr/bin/env bash
# site-icon.sh HOST [FALLBACK_FILE]
# Prints the path of a PNG icon for a website, for browser web notifications
# (Chromium labels them all with its own name and logo).
#   1. the browser's own favicon cache (Favicons SQLite of Chrome/Helium/Brave/...; local, no network)
#   2. https://HOST/favicon.ico (the site already sent us the notification)
#   3. a copy of FALLBACK_FILE (the browser logo the notification came with)
# Results are cached per host for 7 days in ~/.cache/quickshell/notifications/sites.
set -u
host="${1:-}"
fallback="${2:-}"
[[ "$host" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || exit 1   # also keeps the SQL below safe

cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/notifications/sites"
mkdir -p "$cache"
out="$cache/${host//:/_}.png"
if [ -s "$out" ] && [ -n "$(find "$out" -mtime -7 2>/dev/null)" ]; then
    printf %s "$out"; exit 0
fi

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
shopt -s nullglob
bestw=0
# Live profiles only (psd keeps *-backup / *-back-ovfs copies next to them: never touch those).
for db in "$HOME"/.config/{google-chrome,google-chrome-beta,google-chrome-unstable,chromium,net.imput.helium,BraveSoftware/Brave-Browser,BraveSoftware/Brave-Origin,microsoft-edge,vivaldi}/*/Favicons; do
    cp "$db" "$tmp/db" 2>/dev/null || continue   # the browser keeps it locked
    row=$(sqlite3 -readonly "$tmp/db" "select b.width, hex(b.image_data) from icon_mapping m
        join favicon_bitmaps b on b.icon_id = m.icon_id
        where m.page_url like 'https://$host/%' or m.page_url like 'http://$host/%'
        order by b.width desc, b.last_updated desc limit 1" 2>/dev/null)
    [ -n "$row" ] || continue
    w=${row%%|*}
    (( w > bestw )) || continue
    bestw=$w
    printf %s "${row#*|}" | xxd -r -p > "$tmp/best"
done

if [ ! -s "$tmp/best" ]; then
    if curl -sfL --max-time 5 -o "$tmp/fav" "https://$host/favicon.ico"; then
        # .ico can hold several sizes: keep the biggest frame
        magick "$tmp/fav" "png:$tmp/frame-%d.png" 2>/dev/null &&
            cp "$(ls -S "$tmp"/frame-*.png | head -1)" "$tmp/best" 2>/dev/null
    fi
fi

if [ -s "$tmp/best" ] && magick "$tmp/best" "png:$out" 2>/dev/null; then
    printf %s "$out"; exit 0
fi

# No site icon: keep the browser's logo (it deletes its temp copy soon)
if [ -n "$fallback" ] && [ -f "$fallback" ]; then
    icons="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/notifications/icons"
    mkdir -p "$icons"
    h=$(sha1sum < "$fallback" | cut -c1-16)
    cp -n "$fallback" "$icons/$h.png" && printf %s "$icons/$h.png" && exit 0
fi
exit 1
