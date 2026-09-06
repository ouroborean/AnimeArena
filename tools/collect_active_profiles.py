# -*- coding: utf-8 -*-
"""
Collect the in-game profile picture of every USABLE (playable) character into one folder.

"Usable" = the playable roster in webclient/app/roster.json (identical to the char-select order,
176 chars) — i.e. everyone a player can actually field, and NOT the hundreds of extra prof.png files
under assets/images/ that belong to Nexus concepts, retired characters, and alternate art.

Each character's ACTIVE portrait is resolved exactly the way the client does (portraitUrlFor):
portraits.json[path].default first, then char_index.json[path].default as a fallback. That matters —
e.g. Aang's active portrait is "Aang/aangnewprof.png", not the older "aangprof.png".

By DEFAULT this COPIES (safe): the originals stay in assets/images/, so the game keeps working. Use
--move only if you truly want to relocate them — that will break in-game portraits until you also
repoint portraits.json / char_index.json / deploy at the new location.

Collected images larger than 75x75 are downscaled to exactly 75x75 (portraits are square, so this
preserves their aspect ratio); smaller ones are left alone. Only the COPY is resized, never the
source asset. Pass --size N to change the target, or --no-resize to keep original resolution.

Usage (run from anywhere):
  python tools/collect_active_profiles.py                 # copy -> "<repo>/active profiles", downscaled to 75x75
  python tools/collect_active_profiles.py --dest ../out   # copy to a custom folder
  python tools/collect_active_profiles.py --name path     # name files by path_name instead of display name
  python tools/collect_active_profiles.py --size 100      # downscale to 100x100 instead of 75x75
  python tools/collect_active_profiles.py --no-resize     # copy at original resolution
  python tools/collect_active_profiles.py --move          # MOVE instead of copy (breaks in-game paths!)
"""
import argparse
import json
import os
import re
import shutil
import sys

try:
    from PIL import Image
    _RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS   # Pillow >=9.1 moved constants under Resampling
except ImportError:
    Image = None
    _RESAMPLE = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT = os.path.join(ROOT, "webclient", "app")
IMAGES_ROOT = os.path.join(ROOT, "assets", "images")


def _load(name):
    with open(os.path.join(CLIENT, name), encoding="utf-8") as f:
        return json.load(f)


def _sanitize(name):
    # Make a display name safe as a filename on any OS: drop / \ : * ? " < > | and collapse spaces.
    cleaned = re.sub(r'[\\/:*?"<>|]+', "", str(name)).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned or "unnamed"


def resolve_portrait(path_name, portraits, char_index):
    """Relative image path (under assets/images) for a character's default portrait, or None."""
    entry = portraits.get(path_name)
    if entry and entry.get("default"):
        return entry["default"]
    fallback = char_index.get(path_name)
    if fallback and fallback.get("default"):
        return fallback["default"]
    return None


def dest_filename(row, src_rel, style):
    ext = os.path.splitext(src_rel)[1] or ".png"
    if style == "keep":
        return os.path.basename(src_rel)
    if style == "path":
        return row["path_name"] + ext
    return _sanitize(row.get("name") or row["path_name"]) + ext   # "display" (default)


def maybe_resize(path, size):
    """Downscale the image at `path` to exactly size x size if either dimension is larger. Returns
    True if it resized. Only ever touches the copy in the output folder, never the source asset.
    Portraits are square, so an exact square resize preserves their aspect ratio."""
    with Image.open(path) as im:
        if im.width <= size and im.height <= size:
            return False
        resized = im.resize((size, size), _RESAMPLE)
    resized.save(path)   # source is .png; saving to the same path keeps PNG + its RGBA transparency
    return True


def main():
    ap = argparse.ArgumentParser(description="Collect usable characters' profile pictures into one folder.")
    ap.add_argument("--dest", default=os.path.join(ROOT, "active profiles"),
                    help='output folder (default: "<repo>/active profiles")')
    ap.add_argument("--name", choices=["display", "path", "keep"], default="display",
                    help='output filename style: display name (default), path_name, or keep original')
    ap.add_argument("--move", action="store_true",
                    help="MOVE instead of copy — breaks in-game portrait paths until you repoint them")
    ap.add_argument("--size", type=int, default=75,
                    help="downscale any collected image larger than this to exactly SIZE x SIZE (default 75)")
    ap.add_argument("--no-resize", action="store_true", help="keep original resolution, no downscaling")
    args = ap.parse_args()

    do_resize = not args.no_resize
    if do_resize and Image is None:
        print("Pillow is needed to resize images: `pip install Pillow`, or pass --no-resize to skip.")
        sys.exit(1)

    roster = _load("roster.json")
    portraits = _load("portraits.json")
    char_index = _load("char_index.json")

    os.makedirs(args.dest, exist_ok=True)
    verb = "Moving" if args.move else "Copying"
    print("%s %d usable-character profiles -> %s" % (verb, len(roster), args.dest))

    copied, resized, used_names, misses = 0, 0, {}, []
    for row in roster:
        pn = row["path_name"]
        rel = resolve_portrait(pn, portraits, char_index)
        if not rel:
            misses.append((pn, "no portraits/char_index entry"))
            continue
        src = os.path.join(IMAGES_ROOT, rel)
        if not os.path.isfile(src):
            misses.append((pn, "missing file: " + rel))
            continue

        out_name = dest_filename(row, rel, args.name)
        # Guard against two characters mapping to the same output name (shouldn't happen with 'path'/'keep').
        if out_name in used_names:
            base, ext = os.path.splitext(out_name)
            out_name = "%s (%s)%s" % (base, pn, ext)
        used_names[out_name] = pn

        dst = os.path.join(args.dest, out_name)
        if args.move:
            shutil.move(src, dst)
        else:
            shutil.copy2(src, dst)
        copied += 1
        if do_resize and maybe_resize(dst, args.size):   # only the collected copy is touched, never the source
            resized += 1

    print("  %s %d file(s)." % ("moved" if args.move else "copied", copied))
    if do_resize:
        print("  resized %d that were larger than %dx%d (the rest were already <= that)." % (resized, args.size, args.size))
    if misses:
        print("  %d could not be resolved:" % len(misses))
        for pn, why in misses:
            print("    %-20s %s" % (pn, why))
        sys.exit(1)
    if args.move:
        print("  NOTE: originals were MOVED out of assets/images/ — in-game portraits will 404 until you\n"
              "        repoint portraits.json / char_index.json (and the deploy/ mirror) at the new folder.")


if __name__ == "__main__":
    main()
