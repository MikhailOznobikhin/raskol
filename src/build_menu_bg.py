"""Полноэкранный фон меню из фото-референса (cover-кроп 16:9 + грейд)."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\mixao\Downloads\photo_2026-10-26_18-32-36.jpg"
OUT = os.path.join(ROOT, "assets", "art", "menu_bg.png")
W, H = 1280, 720

im = Image.open(SRC).convert("RGB")
k = max(W / im.width, H / im.height)
im = im.resize((int(im.width * k + 1), int(im.height * k + 1)), Image.LANCZOS)
x = (im.width - W) // 2
y = int((im.height - H) * 0.42)
im = im.crop((x, y, x + W, y + H))
im = ImageEnhance.Color(im).enhance(0.85)
im = ImageEnhance.Brightness(im).enhance(0.72)

# виньетка
vig = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(vig)
for i in range(80):
    a = int(235 * (i / 80) ** 1.5)
    d.ellipse([-W * 0.18 + i * 7, -H * 0.18 + i * 5,
               W * 1.18 - i * 7, H * 1.18 - i * 5], outline=a)
im = Image.composite(Image.new("RGB", (W, H), (3, 3, 4)), im, vig.filter(ImageFilter.GaussianBlur(70)))

arr = np.asarray(im).astype(np.float32)
rng = np.random.default_rng(3)
arr += ((rng.random((H, W)) - 0.5) * 10)[..., None]
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(OUT)
print("menu_bg ok")
