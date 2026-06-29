#!/usr/bin/env python3
# coding=utf8
"""
Merged script to patch gapless Braille glyphs and install/reset caches automatically.
Place this script in the target font folder:
~/configs/fonts/Atkynson-Hyperlegible-Mono-NerdFont-Gapless-Braille/patch_and_install.py
"""

import sys
import os
import shutil
import subprocess
import contextlib

@contextlib.contextmanager
def silence_stderr():
    """Silence C-level stderr output (like fontforge warnings)."""
    old_stderr = os.dup(2)
    null_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(null_fd, 2)
    try:
        yield
    finally:
        os.dup2(old_stderr, 2)
        os.close(old_stderr)
        os.close(null_fd)

# Fontforge writes directly to stderr via C library when importing or loading fonts.
# We import it under the silence_stderr context.
with silence_stderr():
    import fontforge

BLEED_HORIZONTAL = 15
# 9 - too little, 10 - enough
BLEED_VERTICAL = 45
# 31 - too little, - enough

# Paths
CLEAN_SRC_DIR = "/private/tmp/claude-501/-Users-egigoka-configs/734d666d-e27a-4044-a216-fb03ae98ff5c/scratchpad/atkinson/unzipped"
NF_CLONE = "/private/tmp/claude-501/-Users-egigoka-configs/734d666d-e27a-4044-a216-fb03ae98ff5c/scratchpad/nerd-fonts"
USER_FONTS_DIR = os.path.expanduser("~/Library/Fonts")

# Current directory where this script sits
DEST_DIR = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, os.path.join(NF_CLONE, "bin", "scripts", "braille"))
from Braille import get_circle_center

ASCII_SAMPLE = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def cell_width(font):
    w = 0
    for ch in ASCII_SAMPLE:
        try:
            gw = font[ord(ch)].width
            if gw > w:
                w = gw
        except Exception:
            pass
    return w if w > 0 else int(font.em * 0.6)

def draw_rect_bleed(pen, center, rx, ry):
    cx, cy = center
    x0 = cx - rx - BLEED_HORIZONTAL
    x1 = cx + rx + BLEED_HORIZONTAL
    y0 = cy - ry - BLEED_VERTICAL
    y1 = cy + ry + BLEED_VERTICAL

    pen.moveTo((x0, y1))
    pen.lineTo((x1, y1))
    pen.lineTo((x1, y0))
    pen.lineTo((x0, y0))
    pen.lineTo((x0, y1))
    pen.closePath()

def draw_braille_glyph_bleed(glyph, idx, width, ymax, ymin, rx, ry):
    pen = glyph.glyphPen()
    for i in range(8):
        if (1 << i) & idx > 0:
            center = get_circle_center(i, width, ymax, ymin)
            draw_rect_bleed(pen, center, rx, ry)
    pen = None

def patch(filename):
    src_path = os.path.join(CLEAN_SRC_DIR, filename)
    dest_path = os.path.join(DEST_DIR, filename)
    
    if not os.path.exists(src_path):
        print(f"Error: Source file {src_path} not found.")
        return False
        
    f = fontforge.open(src_path)
    em = f.em
    ymax = f.os2_typoascent
    ymin = f.os2_typodescent
    width = cell_width(f)
    height = ymax - ymin

    rx = width / 4
    ry = height / 8

    for cp in range(0x2800, 0x28FF + 1):
        idx = cp - 0x2800
        g = f.createChar(cp, f"uni{cp:04X}")
        g.clear()
        g.width = width
        draw_braille_glyph_bleed(g, idx, width, ymax, ymin, rx, ry)

    for cp in range(0x2800, 0x28FF + 1):
        try:
            f[cp].removeOverlap()
        except Exception:
            pass

    f.generate(dest_path)
    f.close()
    print(f"Patched: {filename} (BLEED_HORIZONTAL={BLEED_HORIZONTAL}, BLEED_VERTICAL={BLEED_VERTICAL})")
    return True

def install_and_cache(patched_files):
    print(f"\nCopying {len(patched_files)} font(s) to ~/Library/Fonts/...")
    for f in patched_files:
        src = os.path.join(DEST_DIR, f)
        dst = os.path.join(USER_FONTS_DIR, f)
        shutil.copy2(src, dst)
        print(f"  Installed: {f}")
        
    print("\nClearing macOS font cache...")
    try:
        subprocess.run(["atsutil", "databases", "-remove"], check=True)
        subprocess.run(["atsutil", "server", "-shutdown"], check=True)
        subprocess.run(["atsutil", "server", "-ping"], check=True)
        print("Font cache cleared successfully!")
    except Exception as e:
        print(f"Note: Could not fully reset font cache via atsutil ({e}).")

    print("\nRefreshing Fontconfig cache (may prompt for password)...")
    try:
        subprocess.run(["sudo", "fc-cache"], check=True)
    except Exception as e:
        print(f"Note: Could not refresh fontconfig cache via fc-cache ({e}).")

    print("\nDone! Please restart iTerm2 (⌘Q) to see the updated font.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "single":
        print("Patching ONLY Mono-Regular for fast testing...")
        filenames = ["AtkynsonMonoNerdFontMono-Regular.otf"]
    else:
        print("Patching all 24 fonts (this will take a couple of minutes)...")
        print("Tip: Run with 'single' (python3 patch_and_install.py single) to test just Mono-Regular.")
        filenames = sorted(n for n in os.listdir(CLEAN_SRC_DIR) if n.endswith(".otf"))
        
    patched = []
    with silence_stderr():
        for name in filenames:
            if patch(name):
                patched.append(name)
            
    if patched:
        install_and_cache(patched)
