import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from art import chars, pixelkit
from art.pixelkit import Canvas

frames = []
for d in ("down", "left", "up"):
    for p in chars.poses_idle()[:1] + chars.poses_walk()[:3]:
        frames.append(chars.draw_dwarf(p, d, chars.HERO, gear={"scar": True}))
out = pixelkit.sheet(frames, cols=10, pad=2)
out = pixelkit.grid_preview(out, 5)
out.save(r"C:\Users\mixao\myproject\game\tools\preview_hero.png")
print("ok", out.w, out.h)
