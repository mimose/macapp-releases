#!/usr/bin/env python3
"""生成 DMG 背景图（660×400，含 @2x 的 tiff）。

用法：make-dmg-background.py <应用名> <输出.tiff> [--accent 6fb2a7] [--bg 121417]
画面：中间虚线箭头（应用 → 应用程序），下方中英安装提示，底部一行首次打开被拦截时的放行路径。
图标位置与 make-dmg.sh 一致：应用 (170,190)、Applications (490,190)。依赖 Pillow。
"""
import argparse, os, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("name"); ap.add_argument("out")
ap.add_argument("--accent", default="6fb2a7"); ap.add_argument("--bg", default="121417")
a = ap.parse_args()
rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
ACC, BG = rgb(a.accent), rgb(a.bg)
mix = lambda c, t: tuple(int(BG[i] + (c[i] - BG[i]) * t) for i in range(3))

def font(sz, bold=False):
    for p in ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz, index=(2 if bold else 0))
            except Exception: pass
    return ImageFont.load_default()

def centered(d, W, y, text, f, color):
    d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=color)

def make(s):
    W, H = 660 * s, 400 * s
    im = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), BG)
    ImageDraw.Draw(glow).ellipse((W * .15, H * .05, W * .85, H * .95), fill=mix(ACC, .28))
    im = Image.blend(im, glow.filter(ImageFilter.GaussianBlur(120 * s)), .55)
    d = ImageDraw.Draw(im)
    y, x0, x1 = 190 * s, 262 * s, 398 * s
    for x in range(x0, x1 - 18 * s, 14 * s):
        d.rounded_rectangle((x, y - 2 * s, x + 8 * s, y + 2 * s), radius=2 * s, fill=ACC)
    d.polygon([(x1, y), (x1 - 18 * s, y - 11 * s), (x1 - 18 * s, y + 11 * s)], fill=ACC)
    n = a.name
    centered(d, W, 290 * s, f"Drag {n} to Applications to install", font(17 * s, True), (236, 238, 242))
    centered(d, W, 316 * s, f"把 {n} 拖到「应用程序」即可安装", font(12 * s), (150, 156, 166))
    d.line((180 * s, 346 * s, 480 * s, 346 * s), fill=mix((255, 255, 255), .12), width=s)
    centered(d, W, 354 * s, "Blocked on first open? System Settings → Privacy & Security → Open Anyway", font(11 * s), (125, 131, 141))
    centered(d, W, 371 * s, "首次打开被拦截：系统设置 → 隐私与安全性 → 仍要打开", font(10 * s), (105, 111, 121))
    return im

tmp = tempfile.mkdtemp()
p1, p2 = os.path.join(tmp, "bg.png"), os.path.join(tmp, "bg@2x.png")
make(1).save(p1); make(2).save(p2)
subprocess.run(["tiffutil", "-cathidpicheck", p1, p2, "-out", a.out], check=True, capture_output=True)
print("写入", a.out)
