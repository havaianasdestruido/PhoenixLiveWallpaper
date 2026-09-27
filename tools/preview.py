#!/usr/bin/env python3
"""Render what the wallpaper will look like, without a device or an image library.

tools/preview.py decodes the engine's PNGs by hand (palette PNGs, every filter type),
reproduces the geometry WallpaperEngine.hx uses - AUTO/COVER/FIT/STRETCH, the blurred
fit backdrop, the MULTIPLY tint on menuDesat, the dim layer - and writes a contact
sheet PNG:

    python3 tools/preview.py                     # docs/preview-auto.png
    python3 tools/preview.py --mode cover        # docs/preview-cover.png
    python3 tools/preview.py --screen 1440x3120 --tile 216x468 --dim 20

Only the standard library is used, so this runs anywhere the repo is checked out.
Geometry is computed in screen pixels (exactly like the engine does) and then scaled
into the tile, so what you see is what a 1080x2400 phone would show.
"""
import argparse
import json
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
DOCS = os.path.join(ROOT, "docs")

MODES = {"auto": 0, "cover": 1, "fit": 2, "stretch": 3}
AUTO_CROP_LIMIT = 2.0          # Config.AUTO_CROP_LIMIT
BLUR_SAMPLE = 16               # Config.BLUR_SAMPLE
BLUR_ALPHA = 235               # WallpaperEngine.drawSlide() backdrop alpha
BLUR_SCRIM = 90                # the darkening drawn over the backdrop
BACKDROP = (0x0B, 0x0B, 0x16)  # canvas.drawColor() at the start of every frame


# --------------------------------------------------------------------- png decode
def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(path):
    """-> (width, height, r, g, b, a), one bytearray per plane."""
    blob = open(path, "rb").read()
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s is not a PNG" % path)

    pos, idat, plte, trns = 8, b"", None, None
    width = height = depth = ctype = interlace = 0
    while pos + 8 <= len(blob):
        (length,) = struct.unpack(">I", blob[pos:pos + 4])
        kind = blob[pos + 4:pos + 8]
        body = blob[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _comp, _filt, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            plte = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        pos += 12 + length

    if interlace:
        raise ValueError("%s is interlaced (Adam7), not supported here" % path)
    if ctype != 3:
        raise ValueError("%s is colour type %d; this script handles palette PNGs" % (path, ctype))
    if depth not in (1, 2, 4, 8):
        raise ValueError("%s has bit depth %d" % (path, depth))

    raw = zlib.decompress(idat)
    stride = (width * depth + 7) // 8
    prev = bytearray(stride)
    indices = bytearray(width * height)
    pos = 0
    for y in range(height):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filt == 1:
            for i in range(1, stride):
                line[i] = (line[i] + line[i - 1]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                left = line[i - 1] if i else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                left = line[i - 1] if i else 0
                upleft = prev[i - 1] if i else 0
                line[i] = (line[i] + paeth(left, prev[i], upleft)) & 0xFF
        elif filt != 0:
            raise ValueError("%s: unknown filter %d" % (path, filt))

        base = y * width
        if depth == 8:
            indices[base:base + width] = line[:width]
        else:
            per_byte = 8 // depth
            mask = (1 << depth) - 1
            for slot in range(per_byte):
                shift = (per_byte - 1 - slot) * depth
                table = bytes((i >> shift) & mask for i in range(256))
                count = len(range(base + slot, base + width, per_byte))
                indices[base + slot:base + width:per_byte] = line.translate(table)[:count]
        prev = line

    palette = [bytearray(256) for _ in range(4)]
    palette[3] = bytearray([255]) * 256
    for i in range(len(plte) // 3):
        palette[0][i] = plte[i * 3]
        palette[1][i] = plte[i * 3 + 1]
        palette[2][i] = plte[i * 3 + 2]
    if trns:
        for i, alpha in enumerate(trns):
            palette[3][i] = alpha

    return (width, height) + tuple(indices.translate(p) for p in palette)


# ------------------------------------------------------------------------ scaling
def clamp_byte(v):
    v = int(v + 0.5)
    return 255 if v > 255 else (0 if v < 0 else v)


def sample_region(src, sw, sh, sx, sy, swidth, sheight, dw, dh):
    """Bilinear sample of a (possibly fractional) source window into dw x dh."""
    r, g, b, a = src
    if dw <= 0 or dh <= 0:
        return (bytearray(), bytearray(), bytearray(), bytearray())

    cols = []
    for tx in range(dw):
        fx = sx + (tx + 0.5) * swidth / dw - 0.5
        x0 = int(fx)
        wx = fx - x0
        x0 = min(max(x0, 0), sw - 1)
        x1 = min(x0 + 1, sw - 1)
        cols.append((x0, x1, wx, 1.0 - wx))
    rows = []
    for ty in range(dh):
        fy = sy + (ty + 0.5) * sheight / dh - 0.5
        y0 = int(fy)
        wy = fy - y0
        y0 = min(max(y0, 0), sh - 1)
        y1 = min(y0 + 1, sh - 1)
        rows.append((y0 * sw, y1 * sw, wy, 1.0 - wy))

    out = [bytearray(dw * dh) for _ in range(4)]
    for ty, (b0, b1, wy, iwy) in enumerate(rows):
        o = ty * dw
        for tx, (x0, x1, wx, iwx) in enumerate(cols):
            w00, w10, w01, w11 = iwx * iwy, wx * iwy, iwx * wy, wx * wy
            p, q, s, t = b0 + x0, b0 + x1, b1 + x0, b1 + x1
            i = o + tx
            # the four weights sum to 1.0 mathematically but can overshoot by an
            # epsilon in float, so clamp: a 256 would poison the whole tile.
            out[0][i] = clamp_byte(r[p] * w00 + r[q] * w10 + r[s] * w01 + r[t] * w11)
            out[1][i] = clamp_byte(g[p] * w00 + g[q] * w10 + g[s] * w01 + g[t] * w11)
            out[2][i] = clamp_byte(b[p] * w00 + b[q] * w10 + b[s] * w01 + b[t] * w11)
            out[3][i] = clamp_byte(a[p] * w00 + a[q] * w10 + a[s] * w01 + a[t] * w11)
    return tuple(out)


def resample(src, sw, sh, dw, dh):
    return sample_region(src, sw, sh, 0, 0, sw, sh, dw, dh)


def downsample(src, sw, sh, factor):
    """Box-average shrink.

    Stand-in for Bitmap.createScaledBitmap(src, w / BLUR_SAMPLE, ..., true): the
    real call filters bilinearly, which for an integer ratio is close to averaging
    each factor x factor block. Nearest-neighbour would alias into hard squares.
    """
    dw, dh = max(1, sw // factor), max(1, sh // factor)
    r, g, b, a = src
    out = [bytearray(dw * dh) for _ in range(4)]
    for ty in range(dh):
        y0 = ty * factor
        y1 = min(sh, y0 + factor)
        o = ty * dw
        for tx in range(dw):
            x0 = tx * factor
            x1 = min(sw, x0 + factor)
            n = (y1 - y0) * (x1 - x0)
            sr = sg = sb = sa = 0
            for y in range(y0, y1):
                base = y * sw
                for x in range(x0, x1):
                    i = base + x
                    sr += r[i]
                    sg += g[i]
                    sb += b[i]
                    sa += a[i]
            out[0][o + tx] = sr // n
            out[1][o + tx] = sg // n
            out[2][o + tx] = sb // n
            out[3][o + tx] = sa // n
    return tuple(out), dw, dh


def tint(src, hex_color):
    """PorterDuff.Mode.MULTIPLY, exactly what Slide.colorFilter() attaches."""
    value = int(hex_color.lstrip("#"), 16)
    fa, fr, fg, fb = ((value >> 24) & 0xFF, (value >> 16) & 0xFF,
                      (value >> 8) & 0xFF, value & 0xFF)
    channels = (fr, fg, fb, fa)   # planes are (r, g, b, a)
    return tuple(bytearray((c * channels[i]) // 255 for c in plane) for i, plane in enumerate(src))


# ---------------------------------------------------------------------- compositing
def dst_rect(bw, bh, sw, sh, mode):
    """Mirror of WallpaperEngine.applyRect() / coverRect(), in screen pixels."""
    if mode == MODES["stretch"]:
        return (0, 0, sw, sh)
    if mode == MODES["fit"]:
        s = min(sw / bw, sh / bh)
        dw, dh = int(round(bw * s)), int(round(bh * s))
        return (int(round((sw - dw) / 2)), int(round((sh - dh) / 2)), dw, dh)
    s = max(sw / bw, sh / bh)
    dw, dh = max(int(round(bw * s)), sw), max(int(round(bh * s)), sh)
    return (int(round((sw - dw) / 2)), int(round((sh - dh) / 2)), dw, dh)


def effective_mode(bw, bh, sw, sh, mode):
    """Mirror of WallpaperEngine.effectiveMode()."""
    if mode != MODES["auto"]:
        return mode
    cover = max(sw / bw, sh / bh)
    fit = min(sw / bw, sh / bh)
    if fit <= 0:
        return MODES["cover"]
    return MODES["fit"] if cover / fit > AUTO_CROP_LIMIT else MODES["cover"]


class Canvas:
    def __init__(self, w, h, color=BACKDROP):
        self.w, self.h = w, h
        n = w * h
        self.r = bytearray([color[0]]) * n
        self.g = bytearray([color[1]]) * n
        self.b = bytearray([color[2]]) * n

    def blit(self, src, sw, sh, dx, dy, dw, dh, alpha=255):
        """Draw src scaled into the rect (dx, dy, dw, dh), clipped to the canvas.

        Only the visible part is resampled: in cover mode the rect can be several
        times the canvas, and sampling all of it would be pure waste.
        """
        x0, y0 = max(0, dx), max(0, dy)
        x1, y1 = min(self.w, dx + dw), min(self.h, dy + dh)
        if x1 <= x0 or y1 <= y0:
            return
        cw, ch = x1 - x0, y1 - y0
        sx = (x0 - dx) * sw / dw
        sy = (y0 - dy) * sh / dh
        planes = sample_region(src, sw, sh, sx, sy, cw * sw / dw, ch * sh / dh, cw, ch)
        r, g, b, a = planes
        for y in range(ch):
            srow = y * cw
            drow = (y0 + y) * self.w + x0
            for x in range(cw):
                sa = (a[srow + x] * alpha) // 255
                if sa <= 0:
                    continue
                ia = 255 - sa
                o = drow + x
                i = srow + x
                self.r[o] = (r[i] * sa + self.r[o] * ia) // 255
                self.g[o] = (g[i] * sa + self.g[o] * ia) // 255
                self.b[o] = (b[i] * sa + self.b[o] * ia) // 255

    def fill(self, color, alpha=255):
        """canvas.drawRect() with a solid paint."""
        if alpha <= 0:
            return
        ia = 255 - alpha
        cr, cg, cb = color
        for i in range(self.w * self.h):
            self.r[i] = (cr * alpha + self.r[i] * ia) // 255
            self.g[i] = (cg * alpha + self.g[i] * ia) // 255
            self.b[i] = (cb * alpha + self.b[i] * ia) // 255

    def paste(self, other, ox, oy):
        for y in range(other.h):
            if not 0 <= oy + y < self.h:
                continue
            src = y * other.w
            dst = (oy + y) * self.w + ox
            for x in range(other.w):
                if 0 <= ox + x < self.w:
                    self.r[dst + x] = other.r[src + x]
                    self.g[dst + x] = other.g[src + x]
                    self.b[dst + x] = other.b[src + x]

    def png(self):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            base = y * self.w
            for x in range(self.w):
                raw.append(self.r[base + x])
                raw.append(self.g[base + x])
                raw.append(self.b[base + x])

        def chunk(kind, body):
            return (struct.pack(">I", len(body)) + kind + body
                    + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


DIGITS = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
    "9": "111101111001111",
}


def draw_number(canvas, text, x, y, scale=2, color=(255, 255, 255)):
    """3x5 bitmap digits, so tiles can be numbered without shipping a font."""
    cx = x
    for ch in text:
        glyph = DIGITS.get(ch)
        if glyph:
            for gy in range(5):
                for gx in range(3):
                    if glyph[gy * 3 + gx] != "1":
                        continue
                    for sy in range(scale):
                        for sx in range(scale):
                            px, py = cx + gx * scale + sx, y + gy * scale + sy
                            if 0 <= px < canvas.w and 0 <= py < canvas.h:
                                i = py * canvas.w + px
                                canvas.r[i], canvas.g[i], canvas.b[i] = color
        cx += 4 * scale


def render_slide(slide, tile, screen, mode, dim_pct):
    tile_w, tile_h = tile
    screen_w, screen_h = screen
    path = os.path.join(ASSETS, slide["asset"])
    sw, sh, r, g, b, a = read_png(path)
    src = (r, g, b, a)
    if slide.get("tint"):
        src = tint(src, slide["tint"])

    canvas = Canvas(tile_w, tile_h)
    chosen = effective_mode(sw, sh, screen_w, screen_h, mode)
    scale = tile_w / screen_w          # tile and screen share an aspect ratio

    if chosen == MODES["fit"]:
        small, bw, bh = downsample(src, sw, sh, BLUR_SAMPLE)
        dx, dy, dw, dh = dst_rect(bw, bh, screen_w, screen_h, MODES["cover"])
        canvas.blit(small, bw, bh,
                    int(round(dx * scale)), int(round(dy * scale)),
                    max(1, int(round(dw * scale))), max(1, int(round(dh * scale))),
                    alpha=BLUR_ALPHA)
        canvas.fill((0, 0, 0), alpha=BLUR_SCRIM)

    dx, dy, dw, dh = dst_rect(sw, sh, screen_w, screen_h, chosen)
    canvas.blit(src, sw, sh,
                int(round(dx * scale)), int(round(dy * scale)),
                max(1, int(round(dw * scale))), max(1, int(round(dh * scale))))

    if dim_pct > 0:
        canvas.fill((0, 0, 0), alpha=min(255, int(dim_pct * 2.55)))
    return canvas, chosen


def contact_sheet(slides, tile, screen, mode, dim_pct, columns, gap=8):
    tile_w, tile_h = tile
    rows = (len(slides) + columns - 1) // columns
    sheet = Canvas(columns * tile_w + (columns + 1) * gap,
                   rows * tile_h + (rows + 1) * gap)
    names = {0: "auto", 1: "cover", 2: "fit", 3: "stretch"}
    for n, slide in enumerate(slides):
        tile_canvas, chosen = render_slide(slide, tile, screen, mode, dim_pct)
        ox = gap + (n % columns) * (tile_w + gap)
        oy = gap + (n // columns) * (tile_h + gap)
        sheet.paste(tile_canvas, ox, oy)
        label = str(n + 1)
        draw_number(sheet, label, ox + 9, oy + tile_h - 17, scale=2, color=(0, 0, 0))
        draw_number(sheet, label, ox + 8, oy + tile_h - 18, scale=2, color=(253, 113, 155))
        print("  %2d. %-46s %-8s %s"
              % (n + 1, os.path.basename(slide["asset"]), names[chosen], slide.get("label", "")))
    return sheet


def main():
    parser = argparse.ArgumentParser(
        description="Render the wallpaper slideshow without a device.",
        epilog=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=sorted(MODES), default="auto")
    parser.add_argument("--screen", default="1080x2400", help="device resolution used for the geometry")
    parser.add_argument("--tile", default="216x480", help="preview size of one tile")
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--dim", type=int, default=0, help="dim percentage, as in the settings screen")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()

    playlist = os.path.join(ASSETS, "fnf", "slides.json")
    if not os.path.exists(playlist):
        print("missing %s - run tools/fetch_assets.py first" % playlist, file=sys.stderr)
        return 1
    slides = json.loads(open(playlist, encoding="utf-8").read())["slides"]

    screen = tuple(int(v) for v in args.screen.split("x"))
    tile = tuple(int(v) for v in args.tile.split("x"))
    if abs(tile[0] / tile[1] - screen[0] / screen[1]) > 0.02:
        print("warning: tile aspect %.3f != screen aspect %.3f" %
              (tile[0] / tile[1], screen[0] / screen[1]), file=sys.stderr)

    out = args.out or os.path.join(DOCS, "preview-%s.png" % args.mode)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    print("rendering %d slides, %s mode, %dx%d screen, %dx%d tiles"
          % (len(slides), args.mode, screen[0], screen[1], tile[0], tile[1]))
    sheet = contact_sheet(slides, tile, screen, MODES[args.mode], args.dim, args.columns)
    with open(out, "wb") as fh:
        fh.write(sheet.png())
    print("wrote %s (%dx%d, %.0f KB)" % (out, sheet.w, sheet.h, os.path.getsize(out) / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
