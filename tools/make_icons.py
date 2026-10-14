"""Regenerate every icon from src/assets/icon-original.png (the blue paw from the page's logo).

    python tools/make_icons.py

icon-original.png is rendered from icon-original.html (open it in a browser with a transparent
background, or any SVG renderer). Output: icon-16 … icon-512.png, icon.png and icon.ico.
After changing the picture, bump ICON_VERSION in tools/build.py so browsers drop their cached copies.
Needs Pillow (pip install pillow).
"""
import io
import struct
from pathlib import Path
from PIL import Image, ImageFilter

A = Path(__file__).resolve().parents[1] / 'src' / 'assets'
SMALL = (16, 20, 24, 30, 32, 40)          # 20/30/40 = 16/24/32 at 125 % display scaling
LARGE = (48, 64, 96, 128, 192, 256, 512)
ICO_SIZES = (16, 20, 24, 30, 32, 40, 48, 64, 96, 128, 256)  # the sizes Windows asks for


def trim_square(im, pad=1.02):
    x0, y0, x1, y1 = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    side = int(max(x1 - x0, y1 - y0) * pad)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(im.crop((x0, y0, x1, y1)), ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2))
    return sq


def sized(base, s, sharp):
    im = base.resize((s, s), Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=sharp, threshold=1)) if sharp else im


def write_ico(path, frames):
    """A Windows .ico the way Windows expects it: 32-bit bitmaps (with alpha) below 256 px, PNG only for 256 px.
    Pillow writes every size as PNG; some parts of Windows (the desktop at some icon sizes) cannot read small
    PNG frames and show a blank icon instead."""
    blobs = []
    for im in frames:
        im = im.convert('RGBA')
        w, h = im.size
        if w >= 256:
            buf = io.BytesIO()
            im.save(buf, format='PNG')
            blobs.append((w, h, buf.getvalue()))
            continue
        header = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)  # BITMAPINFOHEADER, height x2 (+ mask)
        px = im.tobytes('raw', 'BGRA')
        rows = [px[y * w * 4:(y + 1) * w * 4] for y in range(h)][::-1]               # bottom-up
        mask_row = ((w + 31) // 32) * 4                                              # 1-bit AND mask, 4-byte rows
        mask = bytearray()
        for y in reversed(range(h)):
            bits = bytearray(mask_row)
            for x in range(w):
                if im.getpixel((x, y))[3] == 0:
                    bits[x // 8] |= 0x80 >> (x % 8)
            mask += bits
        blobs.append((w, h, header + b''.join(rows) + bytes(mask)))
    out = struct.pack('<HHH', 0, 1, len(blobs))
    offset = 6 + 16 * len(blobs)
    for w, h, data in blobs:
        out += struct.pack('<BBBBHHII', w % 256, h % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    Path(path).write_bytes(out + b''.join(data for _, _, data in blobs))


def main():
    base = trim_square(Image.open(A / 'icon-original.png').convert('RGBA'))
    out = {s: sized(base, s, 110) for s in SMALL}
    out.update({s: sized(base, s, 90 if s == 48 else 70 if s == 64 else 0) for s in LARGE})
    for old in A.glob('icon-[0-9]*.png'):
        old.unlink()
    for s, im in out.items():
        im.save(A / f'icon-{s}.png')
    out[256].save(A / 'icon.png')
    write_ico(A / 'icon.ico', [out[s] for s in ICO_SIZES])
    print('icons:', ', '.join(f'{s}px' for s in sorted(out)))


if __name__ == '__main__':
    main()
