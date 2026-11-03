#!/usr/bin/env bash
# optimize-images.sh — resize, compress and convert all raster images under images/
# Outputs are written next to the originals as <name>-1600.webp, <name>-800.webp,
# <name>-1600.jpg (photos) or <name>.webp / <name>.png (graphics/logos).
# Originals are moved to images-src/ (gitignored).
#
# Requires: python3 with Pillow (pip install pillow)

set -euo pipefail
cd "$(dirname "$0")/.."

/usr/bin/python3 - << 'PYEOF'
import os, sys, shutil
from PIL import Image, ImageOps

ROOT = "images"
SRC = "images-src"
PHOTO_MAX = 1600
PHOTO_SMALL = 800
GRAPHIC_MAX = 1200
LOGO_MAX = 400
WEBP_Q = 80
JPEG_Q = 82

def classify(img, path):
    """Return 'logo', 'graphic' or 'photo'."""
    name = os.path.basename(path).lower()
    if "logo" in name:
        return "logo"
    if name.lower().endswith((".jpg", ".jpeg")):
        return "photo"
    # PNG: count unique colors on the full image — photos have >50k, flat graphics <10k
    rgb = img.convert("RGB")
    colors = rgb.getcolors(maxcolors=300000)
    if colors is None or len(colors) > 50000:
        return "photo"
    return "graphic"

def safe_name(name):
    """Replace spaces and special chars with hyphens, lowercase."""
    base = os.path.splitext(name)[0]
    out = []
    for ch in base:
        if ch.isalnum():
            out.append(ch.lower())
        elif ch in (" ", "_", "-"):
            out.append("-")
        else:
            out.append("-")
    return "".join(out).strip("-")

def process(path):
    rel = os.path.relpath(path, ROOT)
    img = Image.open(path)
    img = ImageOps.exif_transpose(img)  # apply EXIF orientation
    kind = classify(img, path)

    orig_w, orig_h = img.size
    dirname = os.path.dirname(path)
    base = os.path.splitext(os.path.basename(path))[0]
    newbase = safe_name(os.path.basename(path))

    # Move original to images-src/
    src_dest = os.path.join(SRC, rel)
    os.makedirs(os.path.dirname(src_dest), exist_ok=True)
    shutil.move(path, src_dest)

    if kind == "photo":
        max_edge = PHOTO_MAX
        # 1600 variant
        w, h = img.size
        if max(w, h) > max_edge:
            ratio = max_edge / max(w, h)
            img_1600 = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
        else:
            img_1600 = img.copy()
        w1600, h1600 = img_1600.size

        # 800 variant
        if max(w, h) > PHOTO_SMALL:
            ratio = PHOTO_SMALL / max(w, h)
            img_800 = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
        else:
            img_800 = img.copy()

        if img_1600.mode in ("RGBA", "P"):
            img_1600 = img_1600.convert("RGB")
            img_800 = img_800.convert("RGB")

        out_1600_webp = os.path.join(dirname, f"{newbase}-1600.webp")
        out_800_webp = os.path.join(dirname, f"{newbase}-800.webp")
        out_1600_jpg = os.path.join(dirname, f"{newbase}-1600.jpg")

        img_1600.save(out_1600_webp, "WEBP", quality=WEBP_Q, method=6)
        img_800.save(out_800_webp, "WEBP", quality=WEBP_Q, method=6)
        img_1600.save(out_1600_jpg, "JPEG", quality=JPEG_Q, progressive=True, optimize=True)

        s1 = os.path.getsize(out_1600_webp)
        s2 = os.path.getsize(out_800_webp)
        s3 = os.path.getsize(out_1600_jpg)
        print(f"  {rel}: {orig_w}x{orig_h} photo -> {newbase}-1600.webp ({s1//1024}K), {newbase}-800.webp ({s2//1024}K), {newbase}-1600.jpg ({s3//1024}K) [{w1600}x{h1600}]")
        return {"base": newbase, "w": w1600, "h": h1600, "kind": "photo"}

    else:
        max_edge = LOGO_MAX if kind == "logo" else GRAPHIC_MAX
        w, h = img.size
        if max(w, h) > max_edge:
            ratio = max_edge / max(w, h)
            img_out = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
        else:
            img_out = img.copy()
        w_out, h_out = img_out.size

        out_webp = os.path.join(dirname, f"{newbase}.webp")
        out_png = os.path.join(dirname, f"{newbase}.png")

        has_alpha = img_out.mode in ("RGBA", "LA") or (img_out.mode == "P" and "transparency" in img_out.info)
        if has_alpha:
            img_out.save(out_webp, "WEBP", lossless=True, quality=90, method=6)
        else:
            # Flat graphic: palette PNG is often smaller; try both
            rgb = img_out.convert("RGB")
            pal = rgb.convert("P", palette=Image.ADAPTIVE, colors=256)
            pal.save(out_png, "PNG", optimize=True)
            rgb.save(out_webp, "WEBP", lossless=True, quality=90, method=6)
            if os.path.getsize(out_webp) < os.path.getsize(out_png):
                os.remove(out_png)
                out_final = out_webp
            else:
                os.remove(out_webp)
                out_final = out_png

        if has_alpha:
            s = os.path.getsize(out_webp)
            print(f"  {rel}: {orig_w}x{orig_h} {kind} -> {newbase}.webp ({s//1024}K) [{w_out}x{h_out}]")
        else:
            s = os.path.getsize(out_final)
            ext = os.path.splitext(out_final)[1]
            print(f"  {rel}: {orig_w}x{orig_h} {kind} -> {newbase}{ext} ({s//1024}K) [{w_out}x{h_out}]")
        return {"base": newbase, "w": w_out, "h": h_out, "kind": kind}

results = {}
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in sorted(filenames):
        if fn.lower().endswith((".jpg", ".jpeg", ".png")):
            path = os.path.join(dirpath, fn)
            info = process(path)
            rel = os.path.relpath(path, ROOT)
            results[rel] = info

# Write a manifest for reference
import json
with open(os.path.join("tools", "image-manifest.json"), "w") as f:
    json.dump(results, f, indent=2)
print(f"\nProcessed {len(results)} images. Manifest: tools/image-manifest.json")
PYEOF
