#!/usr/bin/env python3
"""Build the Google Play store graphics in store/ from the game's own assets.

    python3 tools/make_store_assets.py

* store/icon-512.png       512x512 app icon (from assets/icons/icon.svg, filling the square:
                           Play rounds the corners itself)
* store/feature-graphic.png 1024x500 feature graphic: a v1.1 screenshot without the menu, with
                           the title

Needs Pillow and rsvg-convert (librsvg) or ImageMagick.
"""
import os
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store")
SVG = os.path.join(ROOT, "assets", "icons", "icon.svg")
SHOT = os.path.join(ROOT, "docs", "screenshots", "v1.1", "01-main-menu.jpg")
FONTS = os.path.join(ROOT, "assets", "fonts")
BACKGROUND = (8, 24, 20)


def rasterise(svg: str, size: int) -> Image.Image:
    tmp = tempfile.mkdtemp()
    png = os.path.join(tmp, "icon.png")
    try:
        if shutil.which("rsvg-convert"):
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", png, svg], check=True)
        else:
            subprocess.run(["magick", "-background", "none", "-density", "300", svg, "-resize", f"{size}x{size}", png], check=True)
        return Image.open(png).convert("RGBA")
    finally:
        shutil.rmtree(tmp)


def icon() -> None:
    # Drawn slightly larger and cropped, so the artwork's own rounded background
    # fills the whole square (Play masks the corners itself).
    art = rasterise(SVG, 600)
    square = Image.new("RGBA", (600, 600), BACKGROUND + (255,))
    square.alpha_composite(art)
    square.crop((44, 44, 556, 556)).convert("RGB").save(os.path.join(OUT, "icon-512.png"), optimize=True)


def feature_graphic() -> None:
    shot = Image.open(SHOT).convert("RGB")
    # The right part of the main menu screenshot: the serpent on a ramp, no buttons.
    crop = shot.crop((690, 160, 1920, 160 + int(1230 * 500 / 1024)))
    img = crop.resize((1024, 500), Image.LANCZOS).convert("RGBA")
    # Darken the left side for the title.
    shade = Image.new("L", (1024, 500))
    d = ImageDraw.Draw(shade)
    for x in range(1024):
        d.line([(x, 0), (x, 500)], fill=int(200 * max(0.0, 1.0 - x / 560.0) ** 1.6))
    img = Image.composite(Image.new("RGBA", img.size, (5, 8, 6, 255)), img, shade)
    title = ImageFont.truetype(os.path.join(FONTS, "Cinzel.ttf"), 112)
    title.set_variation_by_axes([800])
    sub = ImageFont.truetype(os.path.join(FONTS, "Outfit.ttf"), 30)
    sub.set_variation_by_axes([400])
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.text((58, 150), "3D SNAKE", font=title, fill=(0, 0, 0, 200))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(img)
    d.text((54, 146), "3D SNAKE", font=title, fill=(246, 222, 160, 255))
    d.line([(58, 290), (380, 290)], fill=(214, 165, 72, 220), width=3)
    d.text((58, 305), "A living serpent. An ancient isle.", font=sub, fill=(225, 230, 220, 255))
    img.convert("RGB").save(os.path.join(OUT, "feature-graphic.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    feature_graphic()
    print("store graphics written to", OUT)
