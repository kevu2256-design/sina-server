#!/usr/bin/env python3
"""Erzeugt die Branding-Bilder des Sina-Server-Installers (PNG, ohne Abhaengigkeiten).

Aufruf: python3 scripts/gen-branding.py
Schreibt logo.png, icon.png und welcome.png in das Calamares-Branding-Verzeichnis.
"""
import os
import struct
import zlib

TARGET = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "iso", "config", "includes.chroot", "etc", "calamares", "branding", "sina",
)

BG = (0x12, 0x2B, 0x45)      # dunkles Marineblau
FG = (0xFF, 0xFF, 0xFF)      # weiss
ACCENT = (0x2E, 0x9B, 0xD6)  # Sina-Blau

# 5x7-Bitmaps der benoetigten Grossbuchstaben
GLYPHS = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    " ": ["00000"] * 7,
}


def text_mask(text, spacing=1):
    """Liefert eine Bitmaske (Liste von Zeilenlisten) fuer den Text."""
    rows = [[] for _ in range(7)]
    for index, char in enumerate(text.upper()):
        glyph = GLYPHS.get(char, GLYPHS[" "])
        for y in range(7):
            rows[y].extend(1 if bit == "1" else 0 for bit in glyph[y])
            if index < len(text) - 1:
                rows[y].extend([0] * spacing)
    return rows


def make_image(width, height, text, scale, top_bias=0.35):
    """Erzeugt ein RGB-Bild mit Text auf Farbverlauf-Hintergrund."""
    pixels = []
    for y in range(height):
        row = []
        for x in range(width):
            # dezenter vertikaler Verlauf
            shift = int((x + y) * 12 / (width + height))
            row.append((min(BG[0] + shift, 255),
                        min(BG[1] + shift, 255),
                        min(BG[2] + shift, 255)))
        pixels.append(row)

    mask = text_mask(text)
    text_w = len(mask[0]) * scale
    text_h = 7 * scale
    start_x = max((width - text_w) // 2, 0)
    start_y = int(height * top_bias)
    for y in range(text_h):
        for x in range(text_w):
            if mask[y // scale][x // scale]:
                px, py = start_x + x, start_y + y
                if 0 <= px < width and 0 <= py < height:
                    pixels[py][px] = FG

    # Akzentlinie unter dem Text
    line_y = min(start_y + text_h + scale * 2, height - 1)
    for x in range(start_x, min(start_x + text_w, width)):
        pixels[line_y][x] = ACCENT
        if line_y + 1 < height:
            pixels[line_y + 1][x] = ACCENT
    return pixels


def write_png(path, pixels):
    height = len(pixels)
    width = len(pixels[0])
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in pixels)

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload +
                struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(data)
    print(f"  {os.path.basename(path)}: {width}x{height} ({len(data)} B)")


def main():
    os.makedirs(TARGET, exist_ok=True)
    print(f"Schreibe Branding-Bilder nach {os.path.normpath(TARGET)}")
    write_png(os.path.join(TARGET, "logo.png"), make_image(256, 256, "SINA", 8, 0.34))
    write_png(os.path.join(TARGET, "icon.png"), make_image(128, 128, "S", 12, 0.20))
    write_png(os.path.join(TARGET, "welcome.png"), make_image(640, 300, "SINA SERVER", 9, 0.30))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
