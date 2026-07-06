#!/usr/bin/env python3
# coding=utf8
"""
Patch powerline separator glyphs (U+E0B0 , U+E0B2 ) with vertical squish.
Run AFTER patch_and_install_braille_bleed.py so braille changes are preserved.
Reads clean originals from CLEAN_SRC_DIR, squishes, merges into DEST_DIR fonts.
"""

import sys
import os
import shutil
import subprocess
import contextlib

@contextlib.contextmanager
def silence_stderr():
    old_stderr = os.dup(2)
    null_fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(null_fd, 2)
    try:
        yield
    finally:
        os.dup2(old_stderr, 2)
        os.close(old_stderr)
        os.close(null_fd)

with silence_stderr():
    import fontforge

# --- Configurable ---
VERTICAL_SQUISH = 0.95   # 1.0 = no change, 0.8 = 80% height
VERTICAL_OFFSET = -20     # shift glyph up (+) or down (-) after squish, in font units

TARGET_CODEPOINTS = [0xE0B0, 0xE0B2]

# Paths
CLEAN_SRC_DIR = "/private/tmp/claude-501/-Users-egigoka-configs/734d666d-e27a-4044-a216-fb03ae98ff5c/scratchpad/atkinson/unzipped"
print(CLEAN_SRC_DIR)
USER_FONTS_DIR = os.path.expanduser("~/Library/Fonts")
DEST_DIR = os.path.dirname(os.path.abspath(__file__))


def squish_glyph(glyph):
    bbox = glyph.boundingBox()  # (xmin, ymin, xmax, ymax)
    if bbox == (0, 0, 0, 0):
        return
    center_y = (bbox[1] + bbox[3]) / 2
    # Scale y around glyph center, then shift by VERTICAL_OFFSET
    dy = center_y * (1 - VERTICAL_SQUISH) + VERTICAL_OFFSET
    glyph.transform((1, 0, 0, VERTICAL_SQUISH, 0, dy))


def patch(filename):
    src_path = os.path.join(CLEAN_SRC_DIR, filename)
    dest_path = os.path.join(DEST_DIR, filename)

    if not os.path.exists(src_path):
        print(f"Error: Source file {src_path} not found.")
        return False

    src_font = fontforge.open(src_path)

    if os.path.exists(dest_path):
        dst_font = fontforge.open(dest_path)
    else:
        # No braille-patched file yet; work on a fresh copy
        dst_font = src_font
        src_font = None

    for cp in TARGET_CODEPOINTS:
        if src_font is not None:
            try:
                src_font[cp]
            except TypeError:
                print(f"  U+{cp:04X} not in source, skipping.")
                continue
            # Copy original (unsquished) glyph from clean source into dest
            src_font.selection.select(("ranges",), cp, cp)
            src_font.copy()
            dst_font.selection.select(("ranges",), cp, cp)
            dst_font.paste()

        try:
            squish_glyph(dst_font[cp])
        except TypeError:
            print(f"  U+{cp:04X} not in dest font, skipping.")

    if src_font is not None:
        src_font.close()

    dst_font.generate(dest_path)
    dst_font.close()
    print(f"Patched: {filename} (VERTICAL_SQUISH={VERTICAL_SQUISH}, VERTICAL_OFFSET={VERTICAL_OFFSET})")
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
    print("Patching all 24 fonts...")
    print("Tip: Run with 'single' to test just Mono-Regular.")
    filenames = sorted(n for n in os.listdir(CLEAN_SRC_DIR) if n.endswith(".otf"))

    patched = []
    with silence_stderr():
        for name in filenames:
            if patch(name):
                patched.append(name)

    if patched:
        install_and_cache(patched)
