#!/bin/bash
SRC="/etc/plasmalogin.conf.d/zz-steamos-autologin.conf"
DEST="/etc/plasmalogin.conf"

[[ -f "$SRC" ]] || exit 0
SESSION=$(grep -oP '^Session=\K.*' "$SRC")
[[ -z "$SESSION" ]] && exit 0

# Only touch Session= inside [Autologin]; other sections may have their own.
if sed -n '/^\[Autologin\]/,/^\[/p' "$DEST" | grep -q '^Session='; then
    sed -i "/^\[Autologin\]/,/^\[/ s|^Session=.*|Session=$SESSION|" "$DEST"
elif grep -q '^\[Autologin\]' "$DEST"; then
    sed -i "/^\[Autologin\]/a Session=$SESSION" "$DEST"
else
    printf '\n[Autologin]\nSession=%s\n' "$SESSION" >> "$DEST"
fi
