#!/usr/bin/env python3
from __future__ import annotations

import math
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from generate_restorix_icons import SCALE, SIZE, W, paste_with_mask, rgba, rounded_mask, vertical_gradient


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Restorix" / "Assets.xcassets"
OUT = ROOT / "Resources" / "IconConcepts"

TILE = tuple(int(v * SCALE) for v in (85, 93, 939, 947))
TILE_RADIUS = int(187 * SCALE)


def s(v):
    return int(round(v * SCALE))


def offset(points, dx=0, dy=0):
    return [(s(x) + s(dx), s(y) + s(dy)) for x, y in points]


def add_tile(img, top, bottom, rim, inner=True):
    mask = rounded_mask((W, W), TILE_RADIUS, TILE)
    base = vertical_gradient((W, W), rgba(top), rgba(bottom))
    paste_with_mask(img, base, mask)
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle(TILE, radius=TILE_RADIUS, outline=rgba(rim, 136), width=s(7))
    if inner:
        d.rounded_rectangle((s(126), s(139), s(898), s(890)), radius=s(135), outline=(255, 255, 255, 46), width=s(4))
        d.rounded_rectangle((s(137), s(151), s(887), s(878)), radius=s(123), outline=(0, 0, 0, 82), width=s(5))
    shine = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine, "RGBA")
    sd.rounded_rectangle((s(110), s(104), s(914), s(280)), radius=s(115), fill=rgba(rim, 22))
    shine.putalpha(shine.getchannel("A").filter(ImageFilter.GaussianBlur(s(18))))
    paste_with_mask(img, shine, mask)
    return d, mask


def shadow_layer(mask, dx, dy, blur, alpha):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shifted = ImageChops.offset(mask, s(dx), s(dy)).filter(ImageFilter.GaussianBlur(s(blur)))
    layer.putalpha(shifted.point(lambda p: int(p * alpha)))
    return layer


def polygon_mask(points):
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def circle_mask(box):
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).ellipse(tuple(s(v) for v in box), fill=255)
    return m


def draw_check(draw, pts, color, shadow=(0, 0, 0, 120), width=36):
    sp = [(s(x) + s(7), s(y) + s(10)) for x, y in pts]
    draw.line(sp, fill=shadow, width=s(width + 8), joint="curve")
    draw.line([(s(x), s(y)) for x, y in pts], fill=rgba(color), width=s(width), joint="curve")


def draw_disk_stack(draw, cx, cy, accent, metal=(220, 231, 238)):
    for i, y in enumerate([cy + 66, cy + 10, cy - 46]):
        fill = tuple(max(0, metal[j] - i * 18) for j in range(3)) + (255,)
        box = (s(cx - 88), s(y - 33), s(cx + 88), s(y + 33))
        draw.rounded_rectangle((box[0], box[1] + s(16), box[2], box[3]), radius=s(16), fill=fill)
        draw.ellipse(box, fill=tuple(min(255, v + 18) for v in fill[:3]) + (255,), outline=(90, 112, 130, 230), width=s(4))
        draw.arc((box[0] + s(12), box[1] + s(12), box[2] - s(12), box[3] - s(4)), 190, 350, fill=rgba(accent, 190), width=s(3))


def concept_orbit_check():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (38, 54, 67), (8, 16, 24), (88, 132, 152))
    box = (s(240), s(220), s(820), s(800))
    d.arc(box, 35, 330, fill=(0, 0, 0, 115), width=s(98))
    d.arc(box, 38, 328, fill=(56, 205, 197, 255), width=s(80))
    d.polygon(offset([(707, 245), (840, 262), (757, 365)]), fill=(56, 205, 197, 255))
    draw_disk_stack(d, 392, 610, (56, 205, 197))
    d.rounded_rectangle((s(505), s(405), s(706), s(662)), radius=s(44), fill=(18, 31, 41, 245), outline=(198, 218, 228, 255), width=s(10))
    draw_check(d, [(550, 550), (598, 600), (680, 493)], (56, 205, 197), width=28)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_vault_seal():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (46, 48, 55), (17, 19, 24), (192, 181, 154))
    d.ellipse((s(254), s(222), s(770), s(738)), fill=(0, 0, 0, 120))
    d.ellipse((s(240), s(206), s(756), s(722)), fill=(54, 59, 65, 255), outline=(223, 207, 164, 255), width=s(14))
    d.ellipse((s(310), s(276), s(686), s(652)), fill=(25, 30, 36, 255), outline=(143, 130, 104, 255), width=s(10))
    for angle in range(0, 360, 45):
        r = math.radians(angle)
        cx = 498 + math.cos(r) * 238
        cy = 464 + math.sin(r) * 238
        d.ellipse((s(cx - 18), s(cy - 18), s(cx + 18), s(cy + 18)), fill=(230, 214, 174, 255), outline=(84, 75, 58, 255), width=s(3))
    d.rounded_rectangle((s(456), s(330), s(540), s(600)), radius=s(42), fill=(14, 18, 22, 255), outline=(219, 204, 165, 255), width=s(8))
    draw_check(d, [(414, 620), (492, 693), (650, 496)], (79, 214, 164), width=34)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_snapshot_layers():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (34, 60, 55), (8, 24, 24), (109, 190, 167))
    colors = [(72, 113, 103), (48, 96, 95), (22, 56, 61)]
    for i, (x, y) in enumerate([(270, 270), (330, 326), (390, 382)]):
        d.rounded_rectangle((s(x), s(y), s(x + 360), s(y + 300)), radius=s(58), fill=(*colors[i], 255), outline=(197, 231, 221, 185), width=s(7))
        d.line((s(x + 46), s(y + 82), s(x + 318), s(y + 82)), fill=(255, 255, 255, 42), width=s(6))
    d.arc((s(262), s(236), s(756), s(730)), 205, 310, fill=(95, 229, 182, 255), width=s(54))
    d.polygon(offset([(270, 502), (326, 375), (398, 488)]), fill=(95, 229, 182, 255))
    draw_check(d, [(472, 560), (543, 628), (681, 452)], (95, 229, 182), width=32)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_time_capsule():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (34, 55, 84), (7, 18, 35), (94, 140, 196))
    d.ellipse((s(258), s(220), s(768), s(730)), fill=(8, 21, 41, 240), outline=(142, 180, 232, 255), width=s(12))
    d.arc((s(314), s(276), s(712), s(674)), 42, 330, fill=(69, 161, 233, 255), width=s(54))
    d.polygon(offset([(661, 295), (764, 322), (692, 404)]), fill=(69, 161, 233, 255))
    d.line((s(512), s(474), s(512), s(332)), fill=(236, 195, 96, 255), width=s(18))
    d.line((s(512), s(474), s(640), s(552)), fill=(236, 195, 96, 255), width=s(18))
    d.ellipse((s(486), s(448), s(538), s(500)), fill=(248, 219, 145, 255), outline=(106, 80, 38, 220), width=s(4))
    d.rounded_rectangle((s(342), s(670), s(682), s(776)), radius=s(50), fill=(213, 225, 236, 255), outline=(77, 109, 143, 255), width=s(7))
    d.line((s(412), s(722), s(612), s(722)), fill=(69, 161, 233, 220), width=s(7))
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_integrity_prism():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (31, 39, 70), (8, 12, 28), (112, 121, 200))
    top = offset([(504, 250), (715, 374), (505, 500), (294, 374)])
    left = offset([(294, 374), (505, 500), (505, 745), (294, 620)])
    right = offset([(715, 374), (505, 500), (505, 745), (715, 620)])
    d.polygon(offset([(x / SCALE + 10, y / SCALE + 18) for x, y in top]), fill=(0, 0, 0, 120))
    d.polygon(top, fill=(78, 123, 202, 255), outline=(209, 223, 252, 200))
    d.polygon(left, fill=(35, 81, 142, 255), outline=(171, 207, 249, 170))
    d.polygon(right, fill=(28, 51, 112, 255), outline=(171, 207, 249, 170))
    d.line((s(323), s(610), s(686), s(395)), fill=(255, 118, 118, 255), width=s(24))
    d.line((s(323), s(650), s(686), s(435)), fill=(74, 221, 196, 255), width=s(18))
    draw_check(d, [(414, 596), (486, 664), (628, 482)], (245, 249, 255), shadow=(8, 16, 34, 130), width=24)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_signal_archive():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (58, 37, 46), (21, 13, 22), (200, 119, 131))
    for i, box in enumerate([(252, 292, 772, 812), (314, 354, 710, 750), (376, 416, 648, 688)]):
        d.arc(tuple(s(v) for v in box), 208, 332, fill=(235, 116, 136, 170 - i * 32), width=s(42 - i * 8))
    d.rounded_rectangle((s(346), s(342), s(690), s(724)), radius=s(82), fill=(38, 24, 35, 255), outline=(244, 172, 179, 210), width=s(9))
    d.ellipse((s(432), s(428), s(604), s(600)), fill=(245, 213, 150, 255), outline=(108, 76, 45, 210), width=s(7))
    d.rounded_rectangle((s(472), s(574), s(564), s(684)), radius=s(24), fill=(245, 213, 150, 255))
    d.line((s(421), s(392), s(615), s(392)), fill=(255, 255, 255, 55), width=s(6))
    d.line((s(420), s(724), s(616), s(724)), fill=(235, 116, 136, 180), width=s(7))
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_minimal_ribbon():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (244, 247, 248), (180, 190, 196), (255, 255, 255), inner=False)
    d.rounded_rectangle((s(138), s(151), s(887), s(878)), radius=s(124), fill=(228, 234, 237, 255), outline=(112, 128, 139, 120), width=s(5))
    ribbon_a = offset([(330, 686), (488, 258), (616, 258), (458, 686)])
    ribbon_b = offset([(526, 338), (720, 338), (545, 765), (354, 765)])
    d.polygon(offset([(x / SCALE + 10, y / SCALE + 12) for x, y in ribbon_a]), fill=(0, 0, 0, 45))
    d.polygon(ribbon_a, fill=(17, 31, 42, 255))
    d.polygon(ribbon_b, fill=(42, 204, 176, 255))
    d.line((s(396), s(706), s(664), s(706)), fill=(17, 31, 42, 255), width=s(34))
    d.line((s(400), s(324), s(672), s(324)), fill=(42, 204, 176, 255), width=s(34))
    draw_check(d, [(420, 548), (494, 620), (637, 438)], (255, 255, 255), shadow=(8, 20, 25, 120), width=28)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def concept_checksum_wave():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d, _ = add_tile(img, (30, 33, 39), (9, 11, 16), (118, 137, 148))
    d.rounded_rectangle((s(246), s(288), s(778), s(722)), radius=s(82), fill=(17, 21, 26, 255), outline=(179, 196, 205, 180), width=s(8))
    bars = [
        (306, 568, 58), (366, 516, 112), (426, 612, 40), (486, 456, 170),
        (546, 504, 122), (606, 582, 62), (666, 438, 206), (726, 536, 96),
    ]
    for x, y, h in bars:
        color = (83, 216, 185, 255) if h > 90 else (137, 154, 166, 255)
        d.rounded_rectangle((s(x), s(y), s(x + 28), s(y + h)), radius=s(14), fill=color)
    d.line((s(298), s(646), s(756), s(646)), fill=(255, 255, 255, 34), width=s(5))
    d.arc((s(280), s(238), s(744), s(702)), 210, 312, fill=(83, 216, 185, 255), width=s(38))
    d.polygon(offset([(280, 520), (327, 420), (386, 510)]), fill=(83, 216, 185, 255))
    draw_check(d, [(382, 760), (472, 842), (652, 620)], (83, 216, 185), shadow=(0, 0, 0, 120), width=34)
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


CONCEPTS = {
    "orbit-check": concept_orbit_check,
    "vault-seal": concept_vault_seal,
    "snapshot-layers": concept_snapshot_layers,
    "time-capsule": concept_time_capsule,
    "integrity-prism": concept_integrity_prism,
    "signal-archive": concept_signal_archive,
    "minimal-ribbon": concept_minimal_ribbon,
    "checksum-wave": concept_checksum_wave,
}

IMAGESET_NAMES = {
    "orbit-check": "RestorixIconOrbitCheck",
    "vault-seal": "RestorixIconVaultSeal",
    "snapshot-layers": "RestorixIconSnapshotLayers",
    "time-capsule": "RestorixIconTimeCapsule",
    "integrity-prism": "RestorixIconIntegrityPrism",
    "signal-archive": "RestorixIconSignalArchive",
    "minimal-ribbon": "RestorixIconMinimalRibbon",
    "checksum-wave": "RestorixIconChecksumWave",
}


def save_imageset(name, icon):
    imageset = ASSETS / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.Resampling.LANCZOS).save(imageset / f"{name}.png")
    icon.save(imageset / f"{name}@2x.png")
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


def make_preview(icons):
    cell_w, cell_h = 330, 370
    pad_x, pad_y = 64, 48
    preview = Image.new("RGBA", (pad_x * 2 + cell_w * 4, pad_y * 2 + cell_h * 2), (243, 245, 247, 255))
    d = ImageDraw.Draw(preview)
    for index, (name, icon) in enumerate(icons.items()):
        col = index % 4
        row = index // 4
        x = pad_x + col * cell_w
        y = pad_y + row * cell_h
        preview.alpha_composite(icon.resize((256, 256), Image.Resampling.LANCZOS), (x + 37, y))
        d.text((x + 37, y + 282), name, fill=(25, 31, 36))
    preview.save(OUT / "restorix-icon-concepts.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {}
    for name, fn in CONCEPTS.items():
        icon = fn()
        icons[name] = icon
        icon.save(OUT / f"restorix-concept-{name}-1024.png")
        save_imageset(IMAGESET_NAMES[name], icon)
    make_preview(icons)


if __name__ == "__main__":
    main()
