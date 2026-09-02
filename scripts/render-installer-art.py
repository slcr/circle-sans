#!/usr/bin/env python3
"""Render the installer's artwork from the font it installs.

Two pieces, both drawn from the variable font that ships in the same release, so
they always show the font the app installs:

  * the app icon: an "Aa" in Circle Sans, white on the brand's rainforest green,
    on the standard macOS icon tile;
  * the disk-image background: the wordmark over a still of the specimen's
    oil-slick film, with a white band below where Finder's black icon label can
    be read (see installer-dmg.py). The film is procedural and seeded, so every
    release gets the same picture, and the dark green icon stands out against it.

    render-installer-art.py --font "fonts/variable/CircleSans[wdth,wght].ttf" \
                            --out build/installer-icon.icns \
                            --dmg-background build/dmg-background.png \
                            --dmg-background-fonts build/dmg-background-fonts.png

Each background is written twice, as NAME.png and NAME@2x.png. The fonts-only
variant is for the image shipped while the app cannot be signed: it holds the
font files themselves, which Font Book installs without any Gatekeeper prompt. Needs Pillow;
iconutil ships with macOS. --keep-iconset keeps the icon PNGs around, which is
handy for looking at the result.
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CANVAS = 1024  # the master; every other size is scaled down from it
TILE = 824  # Apple's template: the tile sits inset on the 1024 canvas
RADIUS = 185  # about 22% of the tile, close enough to the system squircle
GREEN = (0x22, 0x47, 0x37, 255)  # --rainforest, as on the specimen
SCALE = 4  # render big and downsample, so the corners and the type stay smooth

MONO = "/System/Library/Fonts/Menlo.ttc"  # the eyebrow, as on the specimen
# The image is taller than any Finder window will show: Finder anchors it at the
# top and crops the bottom, and how much of the window is content varies with the
# title bar and the path bar, which are the viewer's settings. Everything that
# matters sits above 380 points; the band simply runs on below.
DMG_SIZE = (640, 520)  # points; installer-dmg.py opens the window 640 x 480
DMG_BAND = 292  # where the white band starts

# What the band says, per kind of image. The app installs itself; the fonts-only
# image (shipped while the app cannot be signed) goes through Font Book.
DMG_TEXT = {
    "app": [
        (16, 520, "Double-click the app to install the typeface."),
        (13, 380, "Then quit and reopen the apps you want to use it in."),
    ],
    "fonts": [
        (16, 520, "Select both fonts and double-click them."),
        (13, 380, "Font Book opens: click Install."),
        (13, 380, "Then quit and reopen the apps you want to use it in."),
    ],
}

# The specimen's film, as colour stops from warm to cool: amber through orange and
# magenta into violet and indigo, with cyan where the field peaks.
FILM = [
    (0.00, (0xF6, 0xB3, 0x2E)),
    (0.22, (0xF2, 0x8C, 0x1F)),
    (0.42, (0xE0, 0x3A, 0x6E)),
    (0.60, (0x8E, 0x2C, 0xB4)),
    (0.78, (0x3A, 0x2C, 0x8C)),
    (0.90, (0x24, 0x52, 0x9E)),
    (1.00, (0x3C, 0xE8, 0xC8)),
]

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


def oil_slick(w, h, seed=11):
    """A still of the film: layered smooth noise, warped by more of itself so it
    folds and streams, then coloured through FILM. Warm on the left, where the
    wordmark sits, cooler towards the icon on the right."""
    rng = np.random.default_rng(seed)

    def field(cells_x, cells_y):
        small = Image.fromarray((rng.random((cells_y, cells_x)) * 255).astype("uint8"), "L")
        return np.asarray(small.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255

    base = 0.55 * field(5, 4) + 0.30 * field(9, 7) + 0.15 * field(18, 14)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    t = base
    for amplitude in (0.32, 0.14):  # two passes: broad folds, then finer streams
        dx, dy = field(4, 3) - 0.5, field(4, 3) - 0.5
        sx = np.clip(xs + dx * amplitude * w, 0, w - 1).astype(np.int32)
        sy = np.clip(ys + dy * amplitude * w, 0, h - 1).astype(np.int32)
        t = t[sy, sx]
    t = 0.72 * t + 0.34 * (xs / w) - 0.06  # the warm-to-cool drift across the width
    t = (t - t.min()) / (t.max() - t.min())
    t = t * t * (3 - 2 * t)  # steeper mid-tones: sharper seams between the colours

    positions = np.array([p for p, _ in FILM], dtype=np.float32)
    colours = np.array([c for _, c in FILM], dtype=np.float32)
    rgb = np.stack([np.interp(t, positions, colours[:, i]) for i in range(3)], axis=-1)
    image = Image.fromarray(rgb.clip(0, 255).astype("uint8"), "RGB")
    return image.filter(ImageFilter.GaussianBlur(radius=max(1, w * 0.003))).convert("RGBA")


def render_dmg_background(font_path, scale, variant="app"):
    """The Finder window's backdrop at 1x or 2x. Coordinates below are in points."""
    w, h = DMG_SIZE[0] * scale, DMG_SIZE[1] * scale
    # Render the film once at 2x and scale for 1x, so both sizes show the same picture.
    film = oil_slick(DMG_SIZE[0] * 2, DMG_SIZE[1] * 2)
    image = film if scale == 2 else film.resize((w, h), Image.LANCZOS)
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
        draw.text((x, pt(40)), ch, font=eyebrow, fill=(255, 255, 255, 215))
        x += eyebrow.getlength(ch) + pt(2)

    # The wordmark: "Circle" heavy over "Sans" light, as on the specimen masthead.
    heavy = circle_sans(font_path, pt(92), 600)
    light = circle_sans(font_path, pt(92), 200)
    draw.text((pt(36), pt(62)), "Circle", font=heavy, fill=(255, 255, 255, 255))
    draw.text((pt(36), pt(146)), "Sans", font=light, fill=(255, 255, 255, 255))

    # The instruction, in the band, left of where the Finder labels land.
    y = 312
    for size, weight, line in DMG_TEXT[variant]:
        fill = GREEN if size == 16 else (0x1A, 0x1A, 0x1A, 190)
        draw.text((pt(40), pt(y)), line, font=circle_sans(font_path, pt(size), weight), fill=fill)
        y += 26 if size == 16 else 20
    return image


def write_dmg_background(font_path, path, variant):
    path.parent.mkdir(parents=True, exist_ok=True)
    stem = path.with_suffix("")
    render_dmg_background(font_path, 1, variant).save(stem.with_suffix(".png"), dpi=(72, 72))
    render_dmg_background(font_path, 2, variant).save(pathlib.Path(str(stem) + "@2x.png"), dpi=(144, 144))
    print(f"wrote {stem}.png and {stem}@2x.png ({variant})")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--font", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path, help="the .icns to write")
    parser.add_argument("--keep-iconset", type=pathlib.Path, help="also keep the PNGs here")
    parser.add_argument("--dmg-background", type=pathlib.Path, help="background for the app image: NAME.png and NAME@2x.png")
    parser.add_argument("--dmg-background-fonts", type=pathlib.Path, help="background for the fonts-only image")
    args = parser.parse_args()

    if args.dmg_background:
        write_dmg_background(args.font, args.dmg_background, "app")
    if args.dmg_background_fonts:
        write_dmg_background(args.font, args.dmg_background_fonts, "fonts")

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
