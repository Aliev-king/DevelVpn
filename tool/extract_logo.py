"""Extract the DevelVpn logo into a transparent PNG.

Reads the source image (gray logo on a dark gradient background) and maps
luminance to alpha: background -> transparent, logo -> opaque. The result is
tinted with a single light-gray color so it can be recolored via opacity in
the app.

Usage: python -I extract_logo.py <source_image> <output_png>
"""
import sys

from PIL import Image


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def main() -> None:
    src_path, out_path = sys.argv[1], sys.argv[2]
    lo, hi = float(sys.argv[3]) if len(sys.argv) > 3 else 72.0, \
        float(sys.argv[4]) if len(sys.argv) > 4 else 106.0

    im = Image.open(src_path).convert("L")
    px = im.load()
    w, h = im.size

    out = Image.new("RGBA", (w, h), (235, 235, 235, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            a = round(255.0 * smoothstep(lo, hi, px[x, y]))
            opx[x, y] = (235, 235, 235, a)

    out = out.resize((1024, 1024), Image.LANCZOS)
    out.save(out_path)
    print("saved", out_path)


if __name__ == "__main__":
    main()
