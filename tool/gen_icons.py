"""Hermes Cards 桌面/移动端图标生成（纯标准库，无需 PIL）

设计：薄荷绿圆角底板 + 白色卡片 + 薄荷深绿 H 字母
用法：python3 tool/gen_icons.py
"""
import os
import struct
import zlib

BG = (0x5D, 0xCA, 0xA5)      # AppTheme.mint
CARD = (0xFF, 0xFF, 0xFF)    # 卡片白
GLYPH = (0x1D, 0x9E, 0x75)   # AppTheme.mintDark
SS = 4                        # 超采样倍数（抗锯齿）

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', 'android', 'app', 'src', 'main', 'res')


def squircle_cover(nx, ny, size, radius, inset):
    """返回 (nx,ny) 在圆角矩形内的覆盖率 0..1（nx/ny 已归一化到 0..1）"""
    # 圆角矩形区域：inset..1-inset
    x0 = y0 = inset
    x1 = y1 = 1.0 - inset
    if not (x0 <= nx <= x1 and y0 <= ny <= y1):
        return 0.0
    # 圆角中心
    cx = min(max(nx, x0 + radius), x1 - radius)
    cy = min(max(ny, y0 + radius), y1 - radius)
    dx = nx - cx
    dy = ny - cy
    d = (dx * dx + dy * dy) ** 0.5
    if d <= radius - 0.5 / size:
        return 1.0
    if d >= radius + 0.5 / size:
        return 0.0
    return (radius + 0.5 / size - d) * size


def card_color(nx, ny):
    """卡片（白色圆角矩形）内的覆盖率"""
    if not (0.26 <= nx <= 0.74 and 0.26 <= ny <= 0.74):
        return 0.0
    cx = min(max(nx, 0.26 + 0.10), 0.74 - 0.10)
    cy = min(max(ny, 0.26 + 0.10), 0.74 - 0.10)
    d = ((nx - cx) ** 2 + (ny - cy) ** 2) ** 0.5
    return 1.0 if d <= 0.10 else 0.0


def glyph_cover(nx, ny):
    """H 字母：两根竖条 + 一根横条"""
    for x0, x1 in ((0.385, 0.455), (0.545, 0.615)):
        if x0 <= nx <= x1 and 0.375 <= ny <= 0.625:
            return 1.0
    if 0.435 <= nx <= 0.565 and 0.475 <= ny <= 0.525:
        return 1.0
    return 0.0


def blend(dst, src, a):
    return tuple(int(round(d * (1 - a) + s * a)) for d, s in zip(dst, src))


def render(size):
    """渲染 size×size 的 RGBA 像素矩阵"""
    big = size * SS
    rows = []
    for by in range(big):
        row = []
        for bx in range(big):
            # 用超采样格子的中心点采样
            nx = (bx + 0.5) / big
            ny = (by + 0.5) / big
            a_bg = squircle_cover(nx, ny, big, 0.22, 0.045)
            if a_bg <= 0:
                row.append((0, 0, 0, 0))
                continue
            r, g, b = BG
            a_card = card_color(nx, ny) * a_bg
            if a_card > 0:
                r, g, b = blend((r, g, b), CARD, a_card)
            a_glyph = glyph_cover(nx, ny) * a_bg
            if a_glyph > 0:
                r, g, b = blend((r, g, b), GLYPH, a_glyph)
            row.append((r, g, b, int(round(a_bg * 255))))
        rows.append(row)

    # 4x4 平均下采样
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            acc = [0, 0, 0, 0]
            for dy in range(SS):
                for dx in range(SS):
                    p = rows[y * SS + dy][x * SS + dx]
                    for i in range(4):
                        acc[i] += p[i]
            n = SS * SS
            px = tuple(v // n for v in acc)
            # 预乘转直通 alpha（PNG 需要直通）
            a = px[3]
            if a == 0:
                row.append((0, 0, 0, 0))
            elif a != 255:
                row.append(tuple(
                    min(255, int(round(c * 255 / a))) for c in px[:3]) + (a,))
            else:
                row.append(px)
        out.append(row)
    return out


def write_png(path, pixels):
    h = len(pixels)
    w = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # filter type 0
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', ihdr)
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)


def main():
    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, size in sizes.items():
        d = os.path.join(OUT, folder)
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, 'ic_launcher.png')
        write_png(p, render(size))
        print('生成 %s (%dx%d)' % (p, size, size))


if __name__ == '__main__':
    main()
