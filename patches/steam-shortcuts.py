#!/usr/bin/env python3
# Steamify CachyOS: Steam's non-Steam games list (userdata/<id>/config/
# shortcuts.vdf, binary VDF), for "Add as non-Steam game". Steam reads it only
# at startup and writes it back on exit, so it's edited while Steam is closed.
#   steam-shortcuts.py find   <vdf> <exe>                  -> appid of an entry for exe
#   steam-shortcuts.py add    <vdf> <name> <exe> <icon> <desktop file>
#                                                          -> "added <appid>" / "updated <appid>"
#   steam-shortcuts.py remove <vdf> <appid>
# An entry counts as ours when its Exe is <exe>, or a Steamify start script
# (run-app, also under the pre-2.5.0 path): that one is updated, not doubled.
import os
import struct
import sys
import zlib

MAP, STR, INT, END = 0, 1, 2, 8


def parse(data):
    pos = 0

    def cstr():
        nonlocal pos
        end = data.index(b"\0", pos)
        s = data[pos:end].decode("utf-8", "surrogateescape")
        pos = end + 1
        return s

    def block():
        nonlocal pos
        items = []
        while True:
            t = data[pos]
            pos += 1
            if t == END:
                return items
            key = cstr()
            if t == MAP:
                items.append((key, block()))
            elif t == STR:
                items.append((key, cstr()))
            elif t == INT:
                items.append((key, struct.unpack_from("<I", data, pos)[0]))
                pos += 4
            else:
                raise ValueError(f"unknown VDF type {t} at {pos}")

    if not data:
        return [("shortcuts", [])]
    root = block()
    return root


def dump(items):
    out = bytearray()
    for key, value in items:
        k = key.encode("utf-8", "surrogateescape") + b"\0"
        if isinstance(value, list):
            out += bytes([MAP]) + k + dump(value)
        elif isinstance(value, int):
            out += bytes([INT]) + k + struct.pack("<I", value & 0xFFFFFFFF)
        else:
            out += bytes([STR]) + k + value.encode("utf-8", "surrogateescape") + b"\0"
    return bytes(out) + bytes([END])


def get(entry, key, default=None):
    # Steam's key names vary in case between versions (appid/AppName/Exe).
    for k, v in entry:
        if k.lower() == key.lower():
            return v
    return default


def put(entry, key, value):
    for i, (k, _) in enumerate(entry):
        if k.lower() == key.lower():
            entry[i] = (k, value)
            return
    entry.append((key, value))


def shortcuts(root):
    for k, v in root:
        if k.lower() == "shortcuts":
            return v
    raise ValueError("no shortcuts block")


def ours(entry, exe):
    have = get(entry, "Exe", "").strip('"')
    return have == exe or (have.endswith("/run-app") and
                           ("/steamify/" in have or "/cachyos-gamescope-boot/" in have))


def load(path):
    try:
        with open(path, "rb") as f:
            return parse(f.read())
    except FileNotFoundError:
        return [("shortcuts", [])]


def save(path, root):
    tmp = path + ".steamify-tmp"
    with open(tmp, "wb") as f:
        f.write(dump(root))
    os.replace(tmp, path)


def main(argv):
    cmd, path = argv[1], argv[2]
    root = load(path)
    entries = shortcuts(root)
    if cmd == "find":
        for _, e in entries:
            if ours(e, argv[3]):
                print(get(e, "appid", 0))
                return 0
        return 1
    if cmd == "add":
        name, exe, icon, desktop = argv[3:7]
        for _, e in entries:
            if ours(e, exe):
                put(e, "AppName", name)
                put(e, "Exe", f'"{exe}"')
                put(e, "StartDir", f'"{os.path.dirname(exe)}/"')
                put(e, "icon", icon)
                put(e, "ShortcutPath", desktop)
                save(path, root)
                print("updated", get(e, "appid", 0))
                return 0
        # Steam's own id for a shortcut: CRC32 of exe and name, top bit set.
        appid = (zlib.crc32(f'"{exe}"{name}'.encode()) | 0x80000000) & 0xFFFFFFFF
        entry = [("appid", appid), ("AppName", name), ("Exe", f'"{exe}"'),
                 ("StartDir", f'"{os.path.dirname(exe)}/"'), ("icon", icon),
                 ("ShortcutPath", desktop), ("LaunchOptions", ""), ("IsHidden", 0),
                 ("AllowDesktopConfig", 1), ("AllowOverlay", 1), ("OpenVR", 0),
                 ("Devkit", 0), ("DevkitGameID", ""), ("DevkitOverrideAppID", 0),
                 ("LastPlayTime", 0), ("FlatpakAppID", ""), ("tags", [])]
        entries.append((str(len(entries)), entry))
        if os.path.dirname(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
        save(path, root)
        print("added", appid)
        return 0
    if cmd == "remove":
        keep = [e for _, e in entries if str(get(e, "appid", "")) != argv[3]]
        if len(keep) == len(entries):
            return 0
        entries[:] = [(str(i), e) for i, e in enumerate(keep)]
        save(path, root)
        return 0
    print(f"unknown command {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
