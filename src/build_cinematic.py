"""Сборка кинематиков из AI-видео (Google Flow) и фото-постеров.

Вертикальные 720x1280 приводятся к 16:9 «кинематографической» композицией:
размытый тёмный фон из того же кадра + резкая вертикальная вставка по центру,
виньетка и зерно.

Запуск:
    python src/build_cinematic.py                      # пир Пожирателей (по умолчанию)
    python src/build_cinematic.py <видео.mp4> <имя>    # любой другой клип
    python src/build_cinematic.py <видео.mp4> <имя> <фото.jpg>

Результат: assets/video/<имя>.ogv и assets/art/poster_<имя>.png
"""
from __future__ import annotations

import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FFMPEG = os.path.join(ROOT, "tools", "ffmpeg", "ffmpeg-9.0.2-essentials_build", "bin", "ffmpeg.exe")
DEFAULT_VIDEO = r"C:\Users\mixao\Downloads\video_2026-10-26_18-32-31.mp4"
DEFAULT_PHOTO = r"C:\Users\mixao\Downloads\photo_2026-10-26_18-32-36.jpg"

OUT_VIDEO = os.path.join(ROOT, "assets", "video")
OUT_ART = os.path.join(ROOT, "assets", "art")


def build_video(src: str, name: str) -> None:
    os.makedirs(OUT_VIDEO, exist_ok=True)
    dst = os.path.join(OUT_VIDEO, name + ".ogv")
    if not os.path.exists(FFMPEG):
        print("нет ffmpeg:", FFMPEG)
        return
    if not os.path.exists(src):
        print("нет исходного видео:", src)
        return
    filter_complex = (
        "[0:v]scale=1280:720:force_original_aspect_ratio=increase,"
        "crop=1280:720,boxblur=42:3,eq=brightness=-0.30:saturation=0.35[bg];"
        "[0:v]scale=-2:720[fg];"
        "[bg][fg]overlay=(W-w)/2:0,"
        "vignette=PI/4.4,noise=alls=5:allf=t+u,format=yuv420p[v];"
        "[0:a]volume=0.95[a]"
    )
    cmd = [
        FFMPEG, "-y", "-v", "error",
        "-i", src,
        "-filter_complex", filter_complex,
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libtheora", "-q:v", "9",
        "-c:a", "libvorbis", "-q:a", "4",
        "-r", "24",
        dst,
    ]
    print("ffmpeg:", src, "->", dst)
    subprocess.run(cmd, check=True)
    print("video:", dst, os.path.getsize(dst) // 1024, "КБ")


def _cover(img: Image.Image, w: int, h: int) -> Image.Image:
    k = max(w / img.width, h / img.height)
    out = img.resize((int(img.width * k + 0.5), int(img.height * k + 0.5)), Image.LANCZOS)
    x = (out.width - w) // 2
    y = (out.height - h) // 2
    return out.crop((x, y, x + w, y + h))


def build_poster(src: str, name: str) -> None:
    os.makedirs(OUT_ART, exist_ok=True)
    if not os.path.exists(src):
        print("нет постера:", src)
        return
    photo = Image.open(src).convert("RGB")
    W, H = 1280, 720

    bg = _cover(photo, W, H).filter(ImageFilter.GaussianBlur(42))
    bg = ImageEnhance.Brightness(bg).enhance(0.24)
    bg = ImageEnhance.Color(bg).enhance(0.4)
    canvas = bg.copy()

    fg = photo.resize((int(photo.width * H / photo.height), H), Image.LANCZOS)
    x = (W - fg.width) // 2
    canvas.paste(fg, (x, 0))

    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([x - 3, 0, x + fg.width + 2, H], outline=(8, 6, 6, 220), width=3)
    d.rectangle([x - 1, 0, x, H], fill=(120, 90, 60, 60))

    vig = Image.new("L", (W, H), 0)
    dv = ImageDraw.Draw(vig)
    for i in range(60):
        a = int(255 * (i / 60) ** 1.6)
        dv.ellipse([-W * 0.25 + i * 6, -H * 0.25 + i * 4,
                    W * 1.25 - i * 6, H * 1.25 - i * 4], outline=a)
    canvas = Image.composite(Image.new("RGB", (W, H), (4, 4, 6)), canvas,
                             vig.filter(ImageFilter.GaussianBlur(60)))

    arr = np.asarray(canvas).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    glow = np.clip(1.0 - np.sqrt(((xx - W / 2) / (W * 0.34)) ** 2
                                 + ((yy - H * 0.45) / (H * 0.6)) ** 2), 0, 1) ** 2
    arr[..., 0] += glow * 34
    arr[..., 1] += glow * 18
    arr[..., 2] += glow * 6
    rng = np.random.default_rng(5)
    arr += ((rng.random((H, W)) - 0.5) * 14)[..., None]
    canvas = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    canvas.save(os.path.join(OUT_ART, "poster_%s.png" % name))
    print("poster:", name)


if __name__ == "__main__":
    src_video = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_VIDEO
    name = sys.argv[2] if len(sys.argv) > 2 else "feast"
    src_photo = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_PHOTO
    build_video(src_video, name)
    build_poster(src_photo, name)
