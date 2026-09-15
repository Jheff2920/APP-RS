"""Build Play Store feature graphic 1024x500 from the existing app icon."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
ICON = ROOT / "app-icon-play-512.png"
OUT = ROOT / "play-feature-1024x500.png"
BG = (43, 10, 83)  # #2B0A53
WHITE = (255, 255, 255)
MUTED = (230, 220, 245)

canvas = Image.new("RGB", (1024, 500), BG)
icon = Image.open(ICON).convert("RGB")
icon = icon.resize((320, 320), Image.Resampling.LANCZOS)
canvas.paste(icon, (72, 90))

draw = ImageDraw.Draw(canvas)
fonts = Path(r"C:\Windows\Fonts")
title_font = ImageFont.truetype(str(fonts / "segoeuib.ttf"), 54)
tag_font = ImageFont.truetype(str(fonts / "segoeui.ttf"), 28)

x = 430
draw.text((x, 168), "RedPOS Service", font=title_font, fill=WHITE)
draw.text((x, 248), "Impresión térmica 58/80 mm", font=tag_font, fill=MUTED)
draw.text((x, 292), "Bluetooth  ·  WiFi  ·  USB", font=tag_font, fill=MUTED)

canvas.save(OUT, "PNG", optimize=True)
print(f"wrote {OUT} {canvas.size} {OUT.stat().st_size} bytes")
