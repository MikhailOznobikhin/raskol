import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art import chars, pixelkit

picks = []
picks.append(("hero front", chars.draw_dwarf(chars.Pose(), "down", chars.HERO, gear={"scar": True})))
picks.append(("hero side", chars.draw_dwarf(chars.Pose(), "right", chars.HERO, gear={"scar": True})))
picks.append(("hero back", chars.draw_dwarf(chars.Pose(), "up", chars.HERO, gear={"scar": True})))
picks.append(("hero attack", chars.draw_dwarf(chars.poses_attack()[2], "down", chars.HERO, gear={"scar": True}, weapon="chain")))
picks.append(("guard", chars.draw_dwarf(chars.Pose(), "down", chars.GUARD, helmet=True, beard_len=8, weapon="club")))
picks.append(("guard side", chars.draw_dwarf(chars.Pose(), "right", chars.GUARD, helmet=True, beard_len=8, weapon="club")))
picks.append(("gharn", chars.draw_dwarf(chars.Pose(), "down", chars.GHARN, helmet=True, beard_len=10, beard_wide=15, bulk=3, weapon="whip")))
picks.append(("selena", chars.draw_dwarf(chars.Pose(), "down", chars.SELENA, beard_len=6, beard_wide=8)))
out = pixelkit.sheet([p[1] for p in picks], cols=4, pad=2)
out = pixelkit.grid_preview(out, 8)
out.save(r"C:\Users\mixao\myproject\game\tools\preview_chars.png")
print("ok")
