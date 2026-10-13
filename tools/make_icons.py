"""Regenerate every icon from src/assets/icon-original.png (the blue paw from the page's logo).

    python tools/make_icons.py

icon-original.png is rendered from icon-original.html (open it in a browser with a transparent
background, or any SVG renderer). Output: icon-16 … icon-512.png, icon.png and icon.ico.
After changing the picture, bump ICON_VERSION in tools/build.py so browsers drop their cached copies.
Needs Pillow (pip install pillow).
"""
from pathlib import Path
from PIL import Image, ImageFilter

A = Path(__file__).resolve().parents[1] / 'src' / 'assets'
SMALL = (16, 20, 24, 30, 32, 40)          # 20/30/40 = 16/24/32 at 125 % display scaling
LARGE = (48, 64, 96, 128, 192, 256, 512)


def trim_square(im, pad=1.02):
    x0, y0, x1, y1 = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    side = int(max(x1 - x0, y1 - y0) * pad)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(im.crop((x0, y0, x1, y1)), ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2))
    return sq


def sized(base, s, sharp):
    im = base.resize((s, s), Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=sharp, threshold=1)) if sharp else im


def main():
    base = trim_square(Image.open(A / 'icon-original.png').convert('RGBA'))
    out = {s: sized(base, s, 110) for s in SMALL}
    out.update({s: sized(base, s, 90 if s == 48 else 70 if s == 64 else 0) for s in LARGE})
    for old in A.glob('icon-[0-9]*.png'):
        old.unlink()
    for s, im in out.items():
        im.save(A / f'icon-{s}.png')
    out[256].save(A / 'icon.png')
    ico = [s for s in sorted(out) if s <= 256]
    out[256].save(A / 'icon.ico', format='ICO', sizes=[(s, s) for s in ico], append_images=[out[s] for s in ico if s != 256])
    print('icons:', ', '.join(f'{s}px' for s in sorted(out)))


if __name__ == '__main__':
    main()
