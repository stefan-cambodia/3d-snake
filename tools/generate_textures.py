#!/usr/bin/env python3
"""Generate the game's procedural textures, icons and splash image.

All textures are tileable (built by spectral synthesis, which is periodic by
construction). Re-run after changing parameters:

    python3 tools/generate_textures.py

Requires numpy + Pillow. Outputs into assets/textures and assets/icons.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
ICONS = os.path.join(ROOT, "assets", "icons")
FONTS = os.path.join(ROOT, "assets", "fonts")


def spectral_noise(size, beta, seed, low_cut=1.0):
    """Tileable 1/f^beta noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size))
    fx = np.fft.fftfreq(size)[None, :] * size
    fy = np.fft.fftfreq(size)[:, None] * size
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta)
    amp[f < low_cut] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    out -= out.min()
    out /= max(out.max(), 1e-9)
    return out


def voronoi_cells(size, n, seed):
    """Tileable Worley noise: (F1 distance, F2-F1 edge distance) normalised."""
    rng = np.random.default_rng(seed)
    pts = rng.random((n, 2)) * size
    # Tile the points 3x3 for seamless wrap.
    tiles = np.concatenate([pts + np.array([dx, dy]) * size for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    f1 = np.full((size, size), 1e9, np.float32)
    f2 = np.full((size, size), 1e9, np.float32)
    for p in tiles:
        d = np.sqrt((xx - p[0]) ** 2 + (yy - p[1]) ** 2)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    cell = size / np.sqrt(n)
    return f1 / cell, (f2 - f1) / cell


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    # OpenGL-style normal map (Godot convention: +Y up / green = up).
    n[..., 1] *= -1.0
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save_rgb(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").save(os.path.join(TEX, name), optimize=True)


def stone():
    s = 512
    big = spectral_noise(s, 1.9, 1)
    mid = spectral_noise(s, 1.4, 2)
    fine = spectral_noise(s, 0.9, 3, low_cut=8)
    f1, edge = voronoi_cells(s, 26, 4)
    cracks = np.clip(1.0 - edge / 0.06, 0, 1) ** 2
    blocks = np.clip(edge * 4.0, 0, 1)
    h = 0.45 * big + 0.3 * mid + 0.15 * fine + 0.25 * blocks - 0.5 * cracks
    tone = 0.62 + 0.28 * (mid - 0.5) + 0.18 * (fine - 0.5) - 0.32 * cracks
    warm = np.stack([tone * 1.05, tone * 0.98, tone * 0.88], axis=-1)
    stain = spectral_noise(s, 2.2, 5)
    warm *= (0.85 + 0.25 * stain)[..., None]
    save_rgb(warm * 235, "stone_albedo.png")
    save_rgb(normal_from_height(h, 6.0), "stone_normal.png")


def ground():
    s = 512
    r = spectral_noise(s, 1.1, 11, low_cut=4)   # fine grass clumps
    g = spectral_noise(s, 1.7, 12)              # dirt patches
    f1, edge = voronoi_cells(s, 160, 13)        # pebbles
    pebbles = np.clip(1.0 - f1 * 2.4, 0, 1)
    b = np.clip(pebbles * 0.8 + spectral_noise(s, 0.6, 14, low_cut=16) * 0.3, 0, 1)
    save_rgb(np.stack([r, g, b], axis=-1) * 255, "ground_detail.png")
    h = 0.5 * r + 0.4 * b + 0.2 * g
    save_rgb(normal_from_height(h, 3.5), "ground_normal.png")


def water():
    s = 256
    h = spectral_noise(s, 1.6, 21, low_cut=3) * 0.7 + spectral_noise(s, 1.0, 22, low_cut=10) * 0.3
    save_rgb(normal_from_height(h, 5.0), "water_normal.png")


def clouds():
    s = 512
    n = spectral_noise(s, 2.0, 31) * 0.7 + spectral_noise(s, 1.3, 32, low_cut=6) * 0.3
    c = np.clip((n - 0.45) * 2.6, 0, 1) ** 1.4
    img = (c * 255).astype(np.uint8)
    Image.fromarray(img, "L").save(os.path.join(TEX, "clouds.png"), optimize=True)


ICON_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <radialGradient id="bg" cx="50%" cy="38%" r="75%">
      <stop offset="0" stop-color="#1f5a46"/>
      <stop offset="0.55" stop-color="#0d2a22"/>
      <stop offset="1" stop-color="#06120f"/>
    </radialGradient>
    <linearGradient id="body" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6fd18c"/>
      <stop offset="0.5" stop-color="#2f8f58"/>
      <stop offset="1" stop-color="#14502f"/>
    </linearGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffe7a3"/>
      <stop offset="1" stop-color="#d79a35"/>
    </linearGradient>
    <radialGradient id="eye" cx="45%" cy="40%" r="60%">
      <stop offset="0" stop-color="#ffe680"/>
      <stop offset="1" stop-color="#e08a10"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" rx="112" fill="url(#bg)"/>
  <circle cx="256" cy="256" r="196" fill="none" stroke="url(#gold)" stroke-width="10" opacity="0.85"/>
  <circle cx="256" cy="256" r="176" fill="none" stroke="#d9a548" stroke-width="2" opacity="0.5"/>
  <path d="M150 360 C 95 300, 120 205, 205 190 C 285 176, 330 235, 300 285 C 278 322, 222 318, 214 284 C 207 256, 236 240, 256 252"
        fill="none" stroke="#0a2018" stroke-width="58" stroke-linecap="round" opacity="0.55"/>
  <path d="M150 360 C 95 300, 120 205, 205 190 C 285 176, 330 235, 300 285 C 278 322, 222 318, 214 284 C 207 256, 236 240, 256 252"
        fill="none" stroke="url(#body)" stroke-width="46" stroke-linecap="round"/>
  <path d="M150 360 C 95 300, 120 205, 205 190 C 285 176, 330 235, 300 285"
        fill="none" stroke="#bff2c8" stroke-width="6" stroke-linecap="round" stroke-dasharray="2 22" opacity="0.7"/>
  <path d="M150 360 C 170 395, 230 410, 285 400 L 395 352 C 420 340, 418 312, 392 306 L 290 300 C 240 300, 200 320, 180 340 Z"
        fill="url(#body)" stroke="#0a2018" stroke-width="6"/>
  <ellipse cx="350" cy="322" rx="17" ry="13" fill="url(#eye)" stroke="#0a2018" stroke-width="4"/>
  <ellipse cx="351" cy="322" rx="3.5" ry="11" fill="#120a04"/>
  <path d="M398 336 l 34 10 m -34 -10 l 30 22" stroke="#e2425a" stroke-width="6" stroke-linecap="round"/>
  <circle cx="300" cy="140" r="16" fill="url(#gold)"/>
  <circle cx="300" cy="140" r="30" fill="#ffd27a" opacity="0.18"/>
</svg>
"""


def icons():
    os.makedirs(ICONS, exist_ok=True)
    with open(os.path.join(ICONS, "icon.svg"), "w") as f:
        f.write(ICON_SVG)
    tmp = os.path.join(ICONS, "_icon_full.png")
    rc = os.system(f"magick -background none -density 192 '{os.path.join(ICONS, 'icon.svg')}' -resize 512x512 '{tmp}'")
    if rc != 0:
        print("ImageMagick rasterisation failed", file=sys.stderr)
        sys.exit(1)
    full = Image.open(tmp).convert("RGBA")
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(ICONS, "icon_192.png"))
    # Adaptive icon: 432x432 layers, content inside the central 66% safe zone.
    bg = Image.new("RGBA", (432, 432))
    d = ImageDraw.Draw(bg)
    for i in range(216, 0, -2):
        t = i / 216.0
        c = (int(6 + 25 * (1 - t)), int(18 + 72 * (1 - t)), int(15 + 55 * (1 - t)), 255)
        d.ellipse([216 - i * 1.5, 170 - i * 1.5, 216 + i * 1.5, 170 + i * 1.5], fill=c)
    bg.save(os.path.join(ICONS, "icon_adaptive_bg.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    art = full.resize((300, 300), Image.LANCZOS)
    # Strip the rounded background square: keep only snake/gold strokes by luminance mask.
    a = np.array(art).astype(np.float32)
    lum = a[..., :3].max(axis=-1)
    mask = np.clip((lum - 70) / 40.0, 0, 1) * (a[..., 3] / 255.0)
    a[..., 3] = mask * 255
    fg.alpha_composite(Image.fromarray(a.astype(np.uint8), "RGBA"), (66, 66))
    fg.save(os.path.join(ICONS, "icon_adaptive_fg.png"))
    os.remove(tmp)


def splash():
    w, h = 900, 420
    img = Image.new("RGBA", (w, h), (10, 14, 12, 255))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([w / 2 - 300, h / 2 - 130, w / 2 + 300, h / 2 + 130], fill=(214, 160, 70, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    try:
        title = ImageFont.truetype(os.path.join(FONTS, "Cinzel.ttf"), 86)
        title.set_variation_by_axes([800])
        sub = ImageFont.truetype(os.path.join(FONTS, "Outfit.ttf"), 26)
        sub.set_variation_by_axes([400])
    except Exception:
        title = ImageFont.load_default()
        sub = ImageFont.load_default()
    for text, font, y, col in (("3D SNAKE", title, 165, (246, 222, 160, 255)),):
        tw = d.textlength(text, font=font)
        d.text(((w - tw) / 2 + 3, y + 4), text, font=font, fill=(0, 0, 0, 160))
        d.text(((w - tw) / 2, y), text, font=font, fill=col)
    d.line([(w / 2 - 170, 330), (w / 2 + 170, 330)], fill=(214, 165, 72, 200), width=2)
    s = "a living serpent, an ancient isle"
    tw = d.textlength(s, font=sub)
    d.text(((w - tw) / 2, 345), s, font=sub, fill=(190, 205, 195, 220))
    img.convert("RGB").save(os.path.join(ICONS, "splash.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(TEX, exist_ok=True)
    stone()
    ground()
    water()
    clouds()
    icons()
    splash()
    print("textures and icons generated")
