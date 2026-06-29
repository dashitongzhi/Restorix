#!/usr/bin/env python3
from __future__ import annotations

import math
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Restorix" / "Assets.xcassets"
OUT = ROOT / "Resources" / "IconDesign"
SIZE = 1024
SCALE = 4
W = SIZE * SCALE


VARIANTS = {
    "default": {
        "base_top": (39, 54, 70),
        "base_bottom": (10, 18, 26),
        "rim": (82, 116, 143, 150),
        "accent": (58, 203, 203),
        "accent_dark": (12, 124, 135),
        "metal": (205, 218, 230),
        "metal_dark": (90, 108, 126),
        "line": (31, 65, 76),
    },
    "dimensional": {
        "base_top": (58, 69, 84),
        "base_bottom": (19, 25, 33),
        "rim": (154, 170, 184, 130),
        "accent": (89, 188, 219),
        "accent_dark": (31, 99, 139),
        "metal": (222, 230, 237),
        "metal_dark": (112, 124, 139),
        "line": (47, 69, 88),
    },
    "glass": {
        "base_top": (73, 95, 114),
        "base_bottom": (16, 31, 43),
        "rim": (204, 226, 236, 128),
        "accent": (116, 219, 224),
        "accent_dark": (41, 133, 147),
        "metal": (229, 238, 243),
        "metal_dark": (111, 135, 150),
        "line": (57, 92, 109),
    },
    "neon": {
        "base_top": (22, 36, 51),
        "base_bottom": (4, 9, 15),
        "rim": (40, 231, 224, 95),
        "accent": (36, 236, 220),
        "accent_dark": (1, 111, 124),
        "metal": (188, 211, 224),
        "metal_dark": (62, 91, 114),
        "line": (13, 71, 84),
    },
}


def rgba(color, alpha=255):
    if len(color) == 4:
        return color
    return (*color, alpha)


def rounded_mask(size, radius, box=None):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    if box is None:
        box = (0, 0, size[0], size[1])
    d.rounded_rectangle(box, radius=radius, fill=255)
    return mask


def vertical_gradient(size, top, bottom):
    h = size[1]
    top_arr = np.array(top, dtype=np.float32)
    bottom_arr = np.array(bottom, dtype=np.float32)
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    arr = (top_arr * (1 - t) + bottom_arr * t).astype(np.uint8)
    arr = np.repeat(arr[:, None, :], size[0], axis=1)
    return Image.fromarray(arr, "RGBA")


def paste_with_mask(base, layer, mask):
    base.alpha_composite(Image.composite(layer, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def soft_shadow(size, mask, offset, blur, color):
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    alpha = ImageChops.offset(mask, int(offset[0]), int(offset[1])).filter(ImageFilter.GaussianBlur(blur))
    shadow.putalpha(alpha.point(lambda p: int(p * (color[3] / 255))))
    rgb = Image.new("RGBA", size, color)
    rgb.putalpha(shadow.getchannel("A"))
    return rgb


def draw_disk(draw, cx, cy, w, h, fill, edge, accent):
    box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    draw.rounded_rectangle((box[0], box[1] + h * 0.28, box[2], box[3]), radius=h * 0.18, fill=fill)
    draw.ellipse(box, fill=tuple(min(255, c + 22) for c in fill[:3]) + (255,), outline=edge, width=int(4 * SCALE))
    draw.arc((box[0] + 10 * SCALE, box[1] + 10 * SCALE, box[2] - 10 * SCALE, box[3] - 4 * SCALE), 190, 350, fill=accent, width=int(3 * SCALE))


def draw_icon(variant):
    c = VARIANTS[variant]
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    # Matches the rendered alpha enclosure of Apple's bundled macOS app icons:
    # 256px icns layers measure about (21, 23, 235, 237). Antialiasing expands
    # the drawn rect by about 1px at 1024px, so the source rect is inset by 1px.
    tile = tuple(int(v * SCALE) for v in (85, 93, 939, 947))
    radius = int(187 * SCALE)
    tile_mask = rounded_mask((W, W), radius, tile)

    base = vertical_gradient((W, W), rgba(c["base_top"]), rgba(c["base_bottom"]))
    paste_with_mask(img, base, tile_mask)

    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle(tile, radius=radius, outline=rgba(c["rim"]), width=8 * SCALE)
    inner = tuple(int(v * SCALE) for v in (119, 123, 905, 907))
    d.rounded_rectangle(inner, radius=int(148 * SCALE), outline=(0, 0, 0, 96), width=8 * SCALE)
    d.rounded_rectangle(
        tuple(int(v * SCALE) for v in (139, 149, 885, 887)),
        radius=int(128 * SCALE),
        outline=rgba(c["rim"], 78),
        width=3 * SCALE,
    )

    shine = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine, "RGBA")
    sd.rounded_rectangle(tuple(int(v * SCALE) for v in (103, 92, 921, 278)), radius=int(120 * SCALE), fill=rgba(c["rim"], 22))
    shine.putalpha(shine.getchannel("A").filter(ImageFilter.GaussianBlur(18 * SCALE)))
    paste_with_mask(img, shine, tile_mask)

    # Restore arrow: a thick broken arc with one arrow head, sized inside the tile.
    center = (535 * SCALE, 526 * SCALE)
    arc_box = tuple(int(v * SCALE) for v in (264, 236, 848, 820))
    arc_width = 88 * SCALE
    d.arc(arc_box, 214, 506, fill=(0, 0, 0, 118), width=arc_width + 14 * SCALE)
    d.arc(arc_box, 214, 506, fill=rgba(c["accent_dark"]), width=arc_width)
    d.arc(arc_box, 218, 498, fill=rgba(c["accent"]), width=arc_width - 10 * SCALE)
    d.arc(tuple(int(v * SCALE) for v in (274, 246, 838, 810)), 224, 306, fill=(255, 255, 255, 48), width=10 * SCALE)

    head = [
        (281 * SCALE, 350 * SCALE),
        (432 * SCALE, 302 * SCALE),
        (396 * SCALE, 474 * SCALE),
    ]
    d.polygon([(x + 8 * SCALE, y + 12 * SCALE) for x, y in head], fill=(0, 0, 0, 96))
    d.polygon(head, fill=rgba(c["accent"]))
    d.line([head[0], head[1], head[2], head[0]], fill=(255, 255, 255, 58), width=3 * SCALE, joint="curve")

    # Shield/check: backup integrity, simplified for small sizes.
    shield_shadow = [(455 * SCALE, 427 * SCALE), (655 * SCALE, 490 * SCALE), (655 * SCALE, 657 * SCALE), (555 * SCALE, 732 * SCALE), (455 * SCALE, 657 * SCALE)]
    d.polygon([(x + 10 * SCALE, y + 14 * SCALE) for x, y in shield_shadow], fill=(0, 0, 0, 126))
    shield = [(448 * SCALE, 420 * SCALE), (648 * SCALE, 483 * SCALE), (648 * SCALE, 650 * SCALE), (548 * SCALE, 725 * SCALE), (448 * SCALE, 650 * SCALE)]
    d.polygon(shield, fill=rgba(c["metal_dark"]))
    inset = [(478 * SCALE, 466 * SCALE), (548 * SCALE, 444 * SCALE), (618 * SCALE, 466 * SCALE), (618 * SCALE, 636 * SCALE), (548 * SCALE, 688 * SCALE), (478 * SCALE, 636 * SCALE)]
    d.polygon(inset, fill=(24, 37, 50, 230))
    d.line(shield + [shield[0]], fill=rgba(c["metal"]), width=9 * SCALE, joint="curve")
    d.line([(497 * SCALE, 581 * SCALE), (540 * SCALE, 624 * SCALE), (619 * SCALE, 530 * SCALE)], fill=(0, 0, 0, 130), width=36 * SCALE, joint="curve")
    d.line([(497 * SCALE, 579 * SCALE), (539 * SCALE, 620 * SCALE), (619 * SCALE, 526 * SCALE)], fill=rgba(c["accent"]), width=26 * SCALE, joint="curve")

    # Stacked disks: restore target/source volume, deliberately compact.
    for i, y in enumerate([681, 622, 563]):
        fill = tuple(max(0, min(255, c["metal"][j] - i * 13)) for j in range(3)) + (255,)
        draw_disk(d, 349 * SCALE, y * SCALE, 188 * SCALE, 66 * SCALE, fill, rgba(c["metal_dark"]), rgba(c["accent"], 180))

    # Subtle lower R-tail slice, making the restore arrow read like a mark without becoming text.
    tail = [(639 * SCALE, 717 * SCALE), (758 * SCALE, 838 * SCALE), (617 * SCALE, 838 * SCALE), (536 * SCALE, 757 * SCALE)]
    d.polygon([(x + 7 * SCALE, y + 13 * SCALE) for x, y in tail], fill=(0, 0, 0, 92))
    d.polygon(tail, fill=rgba(c["accent_dark"]))
    d.line([tail[0], tail[1], tail[2], tail[3], tail[0]], fill=rgba(c["accent"], 165), width=5 * SCALE, joint="curve")

    if variant == "glass":
        veil = Image.new("RGBA", (W, W), (255, 255, 255, 0))
        vd = ImageDraw.Draw(veil, "RGBA")
        vd.rounded_rectangle(tuple(int(v * SCALE) for v in (134, 138, 890, 410)), radius=130 * SCALE, fill=(255, 255, 255, 28))
        veil.putalpha(veil.getchannel("A").filter(ImageFilter.GaussianBlur(26 * SCALE)))
        paste_with_mask(img, veil, tile_mask)
    elif variant == "neon":
        glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow, "RGBA")
        gd.arc(arc_box, 214, 506, fill=rgba(c["accent"], 120), width=110 * SCALE)
        glow = glow.filter(ImageFilter.GaussianBlur(12 * SCALE))
        paste_with_mask(img, glow, tile_mask)

    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return img


def save_iconset(source):
    targets = {
        ("16x16", "1x", "icon_16x16.png"): 16,
        ("16x16", "2x", "icon_16x16@2x.png"): 32,
        ("32x32", "1x", "icon_32x32.png"): 32,
        ("32x32", "2x", "icon_32x32@2x.png"): 64,
        ("128x128", "1x", "icon_128x128.png"): 128,
        ("128x128", "2x", "icon_128x128@2x.png"): 256,
        ("256x256", "1x", "icon_256x256.png"): 256,
        ("256x256", "2x", "icon_256x256@2x.png"): 512,
        ("512x512", "1x", "icon_512x512.png"): 512,
        ("512x512", "2x", "icon_512x512@2x.png"): 1024,
    }
    iconset = ASSETS / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    contents = {"images": [], "info": {"author": "xcode", "version": 1}}
    for (slot, scale, name), size in targets.items():
        source.resize((size, size), Image.Resampling.LANCZOS).save(iconset / name)
        contents["images"].append({
            "filename": name,
            "idiom": "mac",
            "scale": scale,
            "size": slot,
        })
    with (iconset / "Contents.json").open("w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def save_imageset(name, img):
    imageset = ASSETS / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    img.resize((512, 512), Image.Resampling.LANCZOS).save(imageset / f"{name}.png")
    img.save(imageset / f"{name}@2x.png")
    contents = {
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with (imageset / "Contents.json").open("w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def save_preview(icons):
    preview = Image.new("RGBA", (1280, 360), (245, 247, 250, 255))
    d = ImageDraw.Draw(preview)
    x = 72
    for label, icon in icons.items():
        preview.alpha_composite(icon.resize((256, 256), Image.Resampling.LANCZOS), (x, 38))
        d.text((x, 314), label, fill=(28, 33, 38))
        x += 302
    preview.save(OUT / "restorix-icon-preview.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {}
    mapping = {
        "default": "RestorixIconDefault",
        "dimensional": "RestorixIconDimensional",
        "glass": "RestorixIconGlass",
        "neon": "RestorixIconNeon",
    }
    for variant, imageset in mapping.items():
        icon = draw_icon(variant)
        icons[variant] = icon
        icon.save(OUT / f"restorix-app-icon-{variant}-1024.png")
        save_imageset(imageset, icon)
    save_iconset(icons["default"])
    save_preview(icons)


if __name__ == "__main__":
    main()
