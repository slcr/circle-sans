#!/usr/bin/env python3
"""Render the installer's artwork from the font it installs.

Two pieces, both drawn from the variable font that ships in the same release, so
they always show the font the app installs:

  * the app icon: an "Aa" in Circle Sans, white on the brand's rainforest green,
    on the standard macOS icon tile;
  * the disk-image background: the wordmark on dark green with a white band
    below, where Finder's black icon label can be read (see installer-dmg.py).

    render-installer-art.py --font "fonts/variable/CircleSans[wdth,wght].ttf" \
                            --out build/installer-icon.icns \
                            --dmg-background build/dmg-background.png

The background is written twice, as NAME.png and NAME@2x.png. Needs Pillow;
iconutil ships with macOS. --keep-iconset keeps the icon PNGs around, which is
handy for looking at the result.
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

CANVAS = 1024  # the master; every other size is scaled down from it
TILE = 824  # Apple's template: the tile sits inset on the 1024 canvas
RADIUS = 185  # about 22% of the tile, close enough to the system squircle
GREEN = (0x22, 0x47, 0x37, 255)  # --rainforest, as on the specimen
SCALE = 4  # render big and downsample, so the corners and the type stay smooth

MONO = "/System/Library/Fonts/Menlo.ttc"  # the eyebrow, as on the specimen
DMG_SIZE = (640, 420)  # points; installer-dmg.py opens the window at this size
DMG_BAND = 296  # where the white band starts

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def set_instance(font, wdth=100, wght=600):
    """Pick Normal width at Semibold; fall back to the default instance quietly."""
    try:
        values = []
        for axis in font.get_variation_axes():
            name = axis["name"]
            name = name.decode() if isinstance(name, bytes) else str(name)
            name = name.lower()
            if "weight" in name:
                values.append(wght)
            elif "width" in name:
                values.append(wdth)
            else:
                values.append(axis["default"])
        font.set_variation_by_axes(values)
    except Exception as exc:  # Pillow without variation support, or a static font
        print(f"note: using the font's default instance ({exc})", file=sys.stderr)


def render_master(font_path):
    size = CANVAS * SCALE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    inset = (CANVAS - TILE) // 2 * SCALE
    draw.rounded_rectangle(
        [inset, inset, size - inset - 1, size - inset - 1],
        radius=RADIUS * SCALE,
        fill=GREEN,
    )

    font = ImageFont.truetype(str(font_path), int(TILE * 0.66 * SCALE))
    set_instance(font)
    text = "Aa"
    left, top, right, bottom = font.getbbox(text)
    ink_w, ink_h = right - left, bottom - top
    # Centre the ink, not the advance box, so the pair sits optically in the tile.
    x = size / 2 - ink_w / 2 - left
    y = size / 2 - ink_h / 2 - top
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

    return image.resize((CANVAS, CANVAS), Image.LANCZOS)


def circle_sans(font_path, size, wght, wdth=100):
    font = ImageFont.truetype(str(font_path), size)
    set_instance(font, wdth=wdth, wght=wght)
    return font


def render_dmg_background(font_path, scale):
    """The Finder window's backdrop at 1x or 2x. Coordinates below are in points."""
    w, h = DMG_SIZE[0] * scale, DMG_SIZE[1] * scale
    image = Image.new("RGBA", (w, h), GREEN)
    draw = ImageDraw.Draw(image)
    pt = lambda v: int(round(v * scale))

    # The band. Finder draws icon labels in black, so the app's label lives here.
    draw.rectangle([0, pt(DMG_BAND), w, h], fill=(255, 255, 255, 255))

    # Eyebrow, tracked like the specimen's mono labels.
    try:
        eyebrow = ImageFont.truetype(MONO, pt(10))
    except OSError:
        eyebrow = ImageFont.load_default()
    x = pt(40)
    for ch in "COFFEE CIRCLE \u00b7 BRAND":
        draw.text((x, pt(40)), ch, font=eyebrow, fill=(255, 255, 255, 180))
        x += eyebrow.getlength(ch) + pt(2)

    # The wordmark: "Circle" heavy over "Sans" light, as on the specimen masthead.
    heavy = circle_sans(font_path, pt(92), 600)
    light = circle_sans(font_path, pt(92), 200)
    draw.text((pt(36), pt(62)), "Circle", font=heavy, fill=(255, 255, 255, 255))
    draw.text((pt(36), pt(146)), "Sans", font=light, fill=(255, 255, 255, 255))

    # The instruction, in the band, left of where the app's own label lands.
    lead = circle_sans(font_path, pt(16), 520)
    rest = circle_sans(font_path, pt(13), 380)
    draw.text((pt(40), pt(320)), "Double-click the app to install the typeface.", font=lead, fill=GREEN)
    draw.text((pt(40), pt(346)), "Then quit and reopen the apps you want to use it in.", font=rest, fill=(0x1a, 0x1a, 0x1a, 190))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--font", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path, help="the .icns to write")
    parser.add_argument("--keep-iconset", type=pathlib.Path, help="also keep the PNGs here")
    parser.add_argument("--dmg-background", type=pathlib.Path, help="write NAME.png and NAME@2x.png here")
    args = parser.parse_args()

    if args.dmg_background:
        args.dmg_background.parent.mkdir(parents=True, exist_ok=True)
        stem = args.dmg_background.with_suffix("")
        render_dmg_background(args.font, 1).save(stem.with_suffix(".png"), dpi=(72, 72))
        render_dmg_background(args.font, 2).save(pathlib.Path(str(stem) + "@2x.png"), dpi=(144, 144))
        print(f"wrote {stem}.png and {stem}@2x.png")

    master = render_master(args.font)

    work = pathlib.Path(tempfile.mkdtemp())
    iconset = work / "installer.iconset"
    iconset.mkdir()
    for name, px in SIZES:
        master.resize((px, px), Image.LANCZOS).save(iconset / name)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(args.out)], check=True)

    if args.keep_iconset:
        if args.keep_iconset.exists():
            shutil.rmtree(args.keep_iconset)
        shutil.copytree(iconset, args.keep_iconset)
    shutil.rmtree(work)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
