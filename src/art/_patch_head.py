"""Одноразовый патч: переписывает голову, бороду и шлем более детально."""
import io, re

PATH = r"C:\Users\mixao\myproject\game\src\art\chars.py"

HEAD = '''def head_front(look: Look, gear: dict):
    """Голова 24x22: сильный контраст, глубокие глазницы, крупный нос."""
    c = Canvas(24, 22)
    skin = P.hx(look.skin)
    skin_d = P.mix(skin, (26, 10, 8, 255), 0.52)
    skin_m = P.mix(skin, (26, 10, 8, 255), 0.26)
    skin_l = P.mix(skin, (255, 228, 196, 255), 0.34)
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 5, 4, 255), 0.62)
    hair_l = P.mix(hair, (255, 210, 160, 255), 0.34)
    eye = P.hx(look.eye)

    # череп, челюсть, скулы
    c.ellipse(2, 1, 21, 18, skin)
    c.rect(7, 15, 16, 19, skin)
    c.rect(8, 18, 15, 19, skin)
    # правая сторона лица в тени
    for y in range(6, 19):
        c.px(20, y, skin_m)
        c.px(19, y, P.mix(skin, skin_m, 0.45))
    c.hline(5, 18, 17, skin_m)
    # виски/лоб
    c.hline(6, 17, 6, skin_l)
    c.hline(6, 17, 7, P.mix(skin_l, skin, 0.5))
    # уши
    c.rect(1, 10, 1, 13, skin)
    c.px(1, 11, skin_d)
    c.rect(22, 10, 22, 13, skin_d)
    # волосы: высокий лоб, космы на висках
    c.ellipse(1, 0, 22, 7, hair)
    c.ellipse(3, 0, 20, 4, hair_d)
    c.rect(15, 1, 21, 3, P.mix(hair, hair_l, 0.5))
    c.rect(0, 4, 2, 11, hair)
    c.rect(21, 4, 23, 11, hair_d)
    c.px(0, 6, hair_l)
    c.rect(4, 4, 19, 5, hair_d)          # кромка волос
    # надбровные дуги
    c.rect(4, 8, 9, 9, hair_d)
    c.rect(14, 8, 19, 9, hair_d)
    c.px(3, 7, hair)
    c.px(20, 7, hair_d)
    # глазницы
    c.rect(4, 10, 9, 11, P.mix(skin_d, (0, 0, 0, 255), 0.45))
    c.rect(14, 10, 19, 11, P.mix(skin_d, (0, 0, 0, 255), 0.45))
    c.rect(5, 10, 8, 10, eye)
    c.rect(15, 10, 18, 10, eye)
    c.px(5, 10, (255, 250, 232, 255))
    c.px(15, 10, (255, 250, 232, 255))
    c.rect(7, 11, 8, 11, P.mix(eye, (0, 0, 0, 255), 0.7))
    c.rect(17, 11, 18, 11, P.mix(eye, (0, 0, 0, 255), 0.7))
    # нос: переносица, спинка, крылья
    c.rect(11, 8, 13, 14, skin)
    c.vline(11, 9, 13, skin_l)
    c.vline(13, 10, 13, skin_m)
    c.rect(10, 14, 14, 15, skin_l)
    c.hline(10, 14, 15, skin_m)
    c.px(9, 15, skin_d)
    c.px(15, 15, skin_d)
    # щёки и морщины
    c.px(6, 13, P.mix(skin_l, skin, 0.4))
    c.px(17, 13, P.mix(skin, skin_m, 0.5))
    c.hline(6, 9, 16, skin_m)
    c.hline(15, 18, 16, skin_m)
    # шрам через левый глаз
    if gear.get("scar"):
        scar = P.mix(skin_l, (214, 116, 106, 255), 0.6)
        c.line([(3, 5), (4, 8), (6, 14)], scar)
        c.px(4, 9, P.mix(scar, (255, 240, 230, 255), 0.3))
        c.px(5, 12, P.mix(scar, skin, 0.35))
    directional_shade(c, lx=-0.55, ly=-0.9, amount=0.2)
    return c


'''

BEARD = '''def beard_front(look: Look, length=17, wide=13, style="full"):
    """Борода: массивный клин с усами, косами и кольцами. 28x(length)."""
    w = wide * 2 + 2
    c = Canvas(w, length)
    cx = w // 2
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 5, 4, 255), 0.6)
    hair_m = P.mix(hair, hair_d, 0.35)
    hair_l = P.mix(hair, (255, 214, 166, 255), 0.3)
    gray = P.hx(look.hair_gray)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)

    # основной клин: чем ниже, тем уже
    for y in range(length):
        t = y / max(1, length - 1)
        half = int(wide * (1 - t * 0.7))
        # волнистая кромка
        wob = 1 if (y * 5) % 7 == 0 else 0
        left = cx - half - wob
        right = cx + half
        c.hline(left, right, y, hair)
        # объём: слева свет, справа тень
        c.vline(left, y, y, hair_d)
        c.hline(left + 1, left + max(2, half // 2), y, hair_m)
        c.vline(right, y, y, hair_d)
        c.px(right - 1, y, hair_d)
        if y % 4 == 0:
            c.hline(left + 2, right - 3, y, P.mix(hair_m, hair_l, 0.45))
    # тень под подбородком (верх бороды)
    c.hline(cx - wide + 1, cx + wide - 1, 0, hair_d)
    c.hline(cx - wide, cx + wide, 1, P.mix(hair, hair_d, 0.5))
    # центральная прядь
    c.vline(cx, 4, length - 2, hair_d)
    c.vline(cx + 1, 5, length - 3, hair_m)
    # усы: расходятся от носа вниз
    for i in range(9):
        x0 = cx - 9 + i
        c.px(x0, 2 + i // 4, hair)
        c.px(x0, 3 + i // 4, hair_d)
    for i in range(9):
        x0 = cx + 1 + i
        c.px(x0, 2 + i // 4, hair_m)
        c.px(x0, 3 + i // 4, hair_d)
    c.hline(cx - 3, cx + 2, 1, hair_d)
    # седина
    for i, x in enumerate((cx - 7, cx - 3, cx + 2, cx + 6)):
        y0 = 6 + (i * 3) % 7
        c.px(x, y0, gray)
        c.px(x, y0 + 1, P.mix(gray, hair_d, 0.5))
        c.px(x + 1, y0 + 2, P.mix(gray, hair_d, 0.65))
    # косы с кольцами
    for side in (-1, 1):
        bx = cx + side * (wide - 3)
        for y in range(8, length - 1, 3):
            c.px(bx, y, hair_m if side < 0 else hair_d)
        ring_y = length - 4
        c.hline(bx - 2, bx + 2, ring_y, metal)
        c.hline(bx - 2, bx + 2, ring_y + 1, P.mix(metal, (0, 0, 0, 255), 0.5))
        c.px(bx - 2, ring_y, metal_l)
        c.px(bx + 2, ring_y - 1, metal_l)
    # низ бороды — тёмный, рваный
    c.hline(cx - 2, cx + 2, length - 1, P.mix(hair_d, (0, 0, 0, 255), 0.35))
    dither_shade(c, (46, 30, 20, 255), 0.05, seed=9)
    return c


'''

HELMET = '''def _helmet(head: Canvas, look: Look, gear: dict, back=False, side=False):
    """Шлем Пожирателей: купол, узкая прорезь с багровым свечением,
    наносник и щёчные пластины."""
    c = head.copy()
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    metal_d = P.hx(look.metal_dark)
    accent = P.hx(look.accent)
    w, h = c.w, c.h
    cx = w // 2

    # купол (уже головы, чтобы читался шлем)
    c.ellipse(1, -2, w - 2, 11, metal)
    c.ellipse(3, -1, w - 4, 7, metal_l)
    c.ellipse(4, 0, 8, 6, P.mix(metal_l, (255, 255, 255, 255), 0.21))
    # нижняя кромка и назатыльник
    c.hline(1, w - 2, 8, metal_d)
    c.rect(1, 9, 3, 14, metal)
    c.rect(w - 4, 9, w - 2, 14, metal_d)
    # гребень
    c.rect(cx - 1, -5, cx + 1, -2, accent)
    c.px(cx, -6, P.mix(accent, (255, 255, 255, 255), 0.35))
    c.hline(cx - 2, cx + 2, -2, P.mix(accent, (0, 0, 0, 255), 0.45))
    # заклёпки по кромке
    for x in (4, 8, 12, 16):
        c.px(x, 8, metal_l)
    if not back:
        # прорезь для глаз
        c.rect(4, 9, w - 5, 10, P.hx("#05060a"))
        if not side:
            c.rect(5, 9, 8, 9, P.hx(look.eye))
            c.rect(w - 9, 9, w - 6, 9, P.hx(look.eye))
            c.px(5, 9, (255, 235, 235, 255))
            c.px(w - 9, 9, (255, 235, 235, 255))
        else:
            c.rect(5, 9, 10, 9, P.hx(look.eye))
        # наносник
        c.rect(cx - 1, 10, cx + 1, 16, metal)
        c.vline(cx - 1, 10, 16, metal_l)
        c.px(cx, 16, metal_d)
        # щёчная пластина
        c.rect(2, 12, 6, 17, metal_d)
        c.rect(w - 7, 12, w - 3, 17, metal_d)
        c.px(3, 15, metal)
        c.px(w - 4, 16, metal_d)
    directional_shade(c, lx=-0.5, ly=-0.95, amount=0.26)
    return c


'''


def replace_block(src: str, start_marker: str, end_marker: str, new: str) -> str:
    i = src.index(start_marker)
    j = src.index(end_marker, i)
    return src[:i] + new + src[j:]


with open(PATH, encoding="utf-8") as f:
    src = f.read()

src = replace_block(src, "def head_front(", "def beard_front(", HEAD)
src = replace_block(src, "def beard_front(", "def head_back(", BEARD)
src = replace_block(src, "def _helmet(", "# ---------------------------------------------------------------------------\n# позы", HELMET)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(src)
print("patched")
