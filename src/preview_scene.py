"""Макет сцены для проверки арт-дирекшена (без Godot)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from art import chars, env, pixelkit
from art.pixelkit import Canvas

W, H, T = 640, 360, 32
rng = random.Random(7)

scene = Canvas(W, H, (6, 8, 13, 255))

# --- пол ---
names = ["floor_0", "floor_1", "floor_2", "floor_0", "floor_2"]
for ty in range(2, 11):
    for tx in range(1, 20):
        name = rng.choice(names)
        scene.blit(env.floor_tile(seed=tx * 100 + ty, variant=rng.randint(0, 2)), tx * T, ty * T)

# --- стены ---
for tx in range(0, 21):
    scene.blit(env.wall_top(seed=tx), tx * T, T)
    scene.blit(env.wall_tile(seed=tx + 40, variant=tx % 3), tx * T, 0)
for ty in range(2, 11):
    scene.blit(env.wall_tile(seed=ty + 70, variant=1), 0, ty * T)
    scene.blit(env.wall_tile(seed=ty + 90, variant=2), 19 * T, ty * T)

# --- декор ---
scene.blit(env.floor_decor("blood", 21), 7 * T, 6 * T)
scene.blit(env.floor_decor("bones", 22), 12 * T, 8 * T)
scene.blit(env.floor_decor("grate", 23), 15 * T, 5 * T)
scene.blit(env.floor_decor("straw", 24), 3 * T, 9 * T)
scene.blit(env.puddle(25), 10 * T, 7 * T)
scene.blit(env.barrel(26), 5 * T, 8 * T)
scene.blit(env.crate(27), 6 * T + 4, 8 * T + 6)
scene.blit(env.straw_bed(28), 2 * T, 4 * T)
scene.blit(env.refuse_pile(29), 16 * T, 9 * T)
scene.blit(env.cauldron(30), 18 * T - 8, 4 * T)
scene.blit(env.chain_hanging(31, 30), 14 * T + 4, 2 * T - 6)
scene.blit(env.cell_door(False), 3 * T, 2 * T)
scene.blit(env.banner(32), 9 * T + 4, 2 * T - 4)

# --- персонажи + тени ---
def shadow(cv, x, y, w=22, h=7, a=110):
    layer = Canvas(W, H)
    layer.d.ellipse([x - w // 2, y - h // 2, x + w // 2, y + h // 2], fill=(0, 0, 0, a))
    cv.img.alpha_composite(layer.img)

shadow(scene, 300, 240, 26, 8, 120)
scene.blit(chars.draw_dwarf(chars.Pose(), "down", chars.HERO, gear={"scar": True}), 276, 178)
shadow(scene, 430, 200, 26, 8, 120)
scene.blit(chars.draw_dwarf(chars.Pose(), "left", chars.GUARD, helmet=True, beard_len=8, weapon="club"), 406, 138)

# --- освещение: факелы + ambient ---
arr = np.asarray(scene.img.convert("RGBA")).astype(np.float32)

amb = np.array([0.78, 0.82, 0.98], dtype=np.float32)   # холодный полумрак
rgb = arr[..., :3] * amb

def add_light(cx, cy, radius, color, intensity):
    x0, x1 = max(0, int(cx - radius)), min(W, int(cx + radius))
    y0, y1 = max(0, int(cy - radius)), min(H, int(cy + radius))
    if x0 >= x1 or y0 >= y1:
        return
    xs = np.arange(x0, x1) - cx
    ys = np.arange(y0, y1) - cy
    d = np.sqrt(xs[None, :] ** 2 + ys[:, None] ** 2) / radius
    fall = np.clip(1 - d, 0, 1) ** 2.2
    for i in range(3):
        rgb[y0:y1, x0:x1, i] += fall * color[i] * intensity

for tx in (4, 11, 17):
    add_light(tx * T + 8, 2 * T + 8, 150, (255, 170, 80), 0.9)
    add_light(tx * T + 8, 2 * T + 8, 40, (255, 220, 160), 0.35)
add_light(18 * T, 4 * T + 8, 70, (255, 120, 60), 0.5)      # котёл
add_light(16 * T + 12, 9 * T + 10, 40, (160, 40, 60), 0.25)  # отбросы

rgb = np.clip(rgb, 0, 255)

# --- виньетка и пар ---
yy, xx = np.mgrid[0:H, 0:W]
cx, cy = W / 2, H / 2
dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
vig = np.clip(dist / 1.5, 0, 1) ** 2.4 * 0.7
rgb = rgb * (1 - vig[..., None])

arr[..., :3] = rgb
out = Image.fromarray(arr.astype(np.uint8), "RGBA").convert("RGB")
# апскейл x2 для просмотра
out = out.resize((W * 2, H * 2), Image.NEAREST)
out.save(r"C:\Users\mixao\myproject\game\tools\preview_scene.png")
print("saved", out.size)
