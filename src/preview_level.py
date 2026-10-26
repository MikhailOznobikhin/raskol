import sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from art import levelart, env, chars, pixelkit

MAP = [
    "########################################",
    "########################################",
    "##........##........##........##.......#",
    "##........##........##........##.......#",
    "##........##........##........##.......#",
    "##........##........##........##.......#",
    "##........##........##........##.......#",
    "########..##########..##########.......#",
    "##....................................#",
    "##....................................#",
    "##....###.........###.................#",
    "##....###.........###.................#",
    "##....###.........###.................#",
    "##....................................#",
    "##....................................#",
    "##..........######....................#",
    "##..........######....................#",
    "##..........######....................#",
    "##....................................#",
    "##....................................#",
    "########################################",
    "########################################",
]

cv = levelart.render_level(MAP, seed=5)
print("level", cv.w, cv.h)

# декор
scene = cv
rng = random.Random(3)
props = [
    (env.straw_bed(1), 70, 70),
    (env.barrel(2), 300, 250),
    (env.crate(3), 330, 262),
    (env.refuse_pile(4), 640, 580),
    (env.cauldron(5), 1000, 260),
    (env.ore_cart(6), 700, 300),
    (env.puddle(7), 420, 420),
]
for p, x, y in props:
    scene.blit(p, x, y)
for x in (120, 420, 760, 1100):
    fr = env.torch_frames(x)[0]
    scene.blit(fr, x, 40)
    scene.blit(env.banner(x + 60), x + 60, 42)
scene.blit(env.cell_door(False), 70, 64)
scene.blit(env.gate(False), 1200, 300)
scene.blit(chars.draw_dwarf(chars.Pose(), "down", chars.HERO, gear={"scar": True}), 380, 300)
scene.blit(chars.draw_dwarf(chars.Pose(), "left", chars.GUARD, helmet=True, beard_len=8, weapon="club"), 620, 260)

# освещение
arr = np.asarray(scene.img.convert("RGBA")).astype(np.float32)
rgb = arr[..., :3] * np.array([0.80, 0.84, 1.0], dtype=np.float32)
H, W = rgb.shape[:2]

def add_light(cx, cy, radius, color, intensity):
    x0, x1 = max(0, int(cx - radius)), min(W, int(cx + radius))
    y0, y1 = max(0, int(cy - radius)), min(H, int(cy + radius))
    if x0 >= x1 or y0 >= y1:
        return
    xs = np.arange(x0, x1) - cx
    ys = np.arange(y0, y1) - cy
    d = np.sqrt(xs[None, :] ** 2 + ys[:, None] ** 2) / radius
    fall = np.clip(1 - d, 0, 1) ** 2.4
    for i in range(3):
        rgb[y0:y1, x0:x1, i] += fall * color[i] * intensity

for x in (120, 420, 760, 1100):
    add_light(x + 8, 48, 150, (255, 168, 78), 0.85)
add_light(1000, 260, 80, (255, 110, 50), 0.4)

yy, xx = np.mgrid[0:H, 0:W]
d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
vig = np.clip(d / 1.5, 0, 1) ** 2.2 * 0.75
rgb = np.clip(rgb, 0, 255) * (1 - vig[..., None])

arr[..., :3] = rgb
out = Image.fromarray(arr.astype(np.uint8), "RGBA").convert("RGB")
out.save(r"C:\Users\mixao\myproject\game\tools\preview_level.png")
print("saved", out.size)
