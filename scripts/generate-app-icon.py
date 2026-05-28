#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "XlyraMonitorIcon.iconset"


def rounded_rectangle_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def make_icon(size):
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Keep the visible icon inside the macOS-style safe area. A transparent
    # outer margin prevents the app switcher from rendering this icon larger
    # than system app icons.
    margin = int(124 * scale)
    tile_rect = (margin, margin, size - margin, size - margin)
    tile_size = size - margin * 2
    tile_mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(tile_mask)
    radius = int(176 * scale)
    mask_draw.rounded_rectangle(tile_rect, radius=radius, fill=255)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (margin, margin + int(18 * scale), size - margin, size - margin + int(18 * scale)),
        radius=radius,
        fill=(0, 0, 0, 80),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(22 * scale)))
    image.alpha_composite(shadow)

    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile_draw = ImageDraw.Draw(tile)
    tile_draw.rounded_rectangle(
        tile_rect,
        radius=radius,
        fill=(18, 28, 36, 255),
    )
    tile_draw.rounded_rectangle(
        tile_rect,
        radius=radius,
        outline=(56, 214, 170, 255),
        width=max(1, int(14 * scale)),
    )

    gradient = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gradient_draw = ImageDraw.Draw(gradient)
    for i in range(margin, size - margin):
        alpha = int(76 * (1 - (i - margin) / tile_size))
        gradient_draw.line((margin, i, size - margin, i), fill=(35, 166, 218, alpha), width=1)
    tile.alpha_composite(Image.composite(gradient, Image.new("RGBA", (size, size), (0, 0, 0, 0)), tile_mask))

    image.alpha_composite(tile)
    draw = ImageDraw.Draw(image)

    cx = size // 2
    cy = margin + int(tile_size * 0.55)
    outer = int(tile_size * 0.34)
    inner = int(tile_size * 0.24)
    width = max(2, int(30 * scale))
    bbox = (cx - outer, cy - outer, cx + outer, cy + outer)

    draw.arc(bbox, 205, 335, fill=(67, 226, 180, 255), width=width)
    draw.arc(bbox, 335, 385, fill=(250, 202, 73, 255), width=width)
    draw.arc(bbox, 155, 205, fill=(245, 96, 91, 255), width=width)

    for angle in (205, 245, 285, 325):
        import math

        rad = math.radians(angle)
        x1 = cx + int((inner + 18 * scale) * math.cos(rad))
        y1 = cy + int((inner + 18 * scale) * math.sin(rad))
        x2 = cx + int((outer - 18 * scale) * math.cos(rad))
        y2 = cy + int((outer - 18 * scale) * math.sin(rad))
        draw.line((x1, y1, x2, y2), fill=(226, 238, 242, 210), width=max(2, int(8 * scale)))

    import math

    needle_angle = math.radians(318)
    needle_end = (
        cx + int((inner + 70 * scale) * math.cos(needle_angle)),
        cy + int((inner + 70 * scale) * math.sin(needle_angle)),
    )
    draw.line((cx, cy, needle_end[0], needle_end[1]), fill=(246, 250, 252, 255), width=max(3, int(24 * scale)))
    draw.ellipse(
        (cx - int(45 * scale), cy - int(45 * scale), cx + int(45 * scale), cy + int(45 * scale)),
        fill=(67, 226, 180, 255),
    )

    bar_y = margin + int(tile_size * 0.75)
    bar_w = int(tile_size * 0.50)
    bar_h = int(30 * scale)
    draw.rounded_rectangle(
        (cx - bar_w // 2, bar_y, cx + bar_w // 2, bar_y + bar_h),
        radius=bar_h // 2,
        fill=(226, 238, 242, 50),
    )
    draw.rounded_rectangle(
        (cx - bar_w // 2, bar_y, cx + int(bar_w * 0.22), bar_y + bar_h),
        radius=bar_h // 2,
        fill=(67, 226, 180, 255),
    )
    draw.rounded_rectangle(
        (cx - bar_w // 2, bar_y + int(52 * scale), cx + bar_w // 2, bar_y + int(52 * scale) + bar_h),
        radius=bar_h // 2,
        fill=(226, 238, 242, 50),
    )
    draw.rounded_rectangle(
        (cx - bar_w // 2, bar_y + int(52 * scale), cx + int(bar_w * 0.36), bar_y + int(52 * scale) + bar_h),
        radius=bar_h // 2,
        fill=(250, 202, 73, 255),
    )
    return image


def main():
    RESOURCES.mkdir(exist_ok=True)
    ICONSET.mkdir(exist_ok=True)
    specs = [
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
    base = make_icon(1024)
    for filename, pixel_size in specs:
        resized = base.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        resized.save(ICONSET / filename)


if __name__ == "__main__":
    main()
