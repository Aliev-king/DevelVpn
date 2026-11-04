"""Generate Android launcher icons from the extracted logo.

Produces legacy mipmaps (square + round) and adaptive-icon assets
(foreground PNGs + XML/color resources) in the Android res folder.

Usage: python -I make_icons.py <logo_png> <res_dir>
"""
import os
import sys

from PIL import Image, ImageDraw

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
BASE_LEGACY = 48
BASE_ADAPTIVE = 108
BACKGROUND = (13, 13, 13, 255)

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""


def logo_canvas(logo: Image.Image, size: int, scale: float) -> Image.Image:
    """Return a size x size transparent canvas with the logo centered at `scale`."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = round(size * scale)
    glyph = logo.resize((inner, inner), Image.LANCZOS)
    offset = ((size - inner) // 2, (size - inner) // 2)
    canvas.alpha_composite(glyph, offset)
    return canvas


def main() -> None:
    logo_path, res_dir = sys.argv[1], sys.argv[2]
    logo = Image.open(logo_path).convert("RGBA")

    for dpi, factor in DENSITIES.items():
        dpi_dir = os.path.join(res_dir, f"mipmap-{dpi}")
        os.makedirs(dpi_dir, exist_ok=True)

        # Legacy square icon: full-bleed dark square with the logo.
        legacy = logo_canvas(logo, round(BASE_LEGACY * factor), 0.62)
        Image.alpha_composite(Image.new("RGBA", legacy.size, BACKGROUND), legacy).convert(
            "RGBA"
        ).save(os.path.join(dpi_dir, "ic_launcher.png"))

        # Legacy round icon: dark circle with the logo.
        legacy_px = round(BASE_LEGACY * factor)
        round_icon = Image.new("RGBA", (legacy_px, legacy_px), (0, 0, 0, 0))
        mask = Image.new("L", (legacy_px, legacy_px), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, legacy_px - 1, legacy_px - 1), fill=255)
        dark = Image.new("RGBA", (legacy_px, legacy_px), BACKGROUND)
        round_icon = Image.composite(
            Image.alpha_composite(dark, legacy), round_icon, mask
        )
        round_icon.save(os.path.join(dpi_dir, "ic_launcher_round.png"))

        # Adaptive icon foreground: transparent, logo inside the safe zone.
        fg = logo_canvas(logo, round(BASE_ADAPTIVE * factor), 0.42)
        fg.save(os.path.join(dpi_dir, "ic_launcher_foreground.png"))

    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi_dir, name), "w", encoding="utf-8") as f:
            f.write(ADAPTIVE_XML)

    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write('<resources>\n    <color name="ic_launcher_background">#0D0D0D</color>\n</resources>\n')

    print("icons written to", res_dir)


if __name__ == "__main__":
    main()
