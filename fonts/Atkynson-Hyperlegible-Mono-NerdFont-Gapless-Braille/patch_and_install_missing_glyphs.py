#!/usr/bin/env python3
# coding=utf8
"""
Fill the gaps in the Atkynson fonts with monospaced glyphs: Cyrillic, Greek,
extended Latin, IPA, arrows, geometric shapes, the backtick, and so on.

Upstream Atkinson Hyperlegible Mono covers little beyond basic Latin, so
terminals fall back to a proportional system font for everything else. This
script adds every codepoint that Source Code Pro (SIL OFL 1.1) has and the
font lacks:
  * glyphs with an identical twin already in the font (А = A, ο = o,
    ` = combining grave, ...) reuse the font's own outlines;
  * everything else comes from Source Code Pro, interpolated to the stem
    weight of each target font, stretched to the 632-unit cell and slanted
    for the italic styles.

Existing glyphs are never touched. Patches the fonts in DEST_DIR in place, so
braille/powerline patches are kept. Safe to re-run: added glyphs carry a
".patched" name suffix and are rebuilt from scratch every time.

Usage:
  python3 patch_and_install_missing_glyphs.py                  # all 24 fonts + install
  python3 patch_and_install_missing_glyphs.py single           # Mono-Regular only + install
  python3 patch_and_install_missing_glyphs.py --out DIR [...]  # write to DIR, no install
"""

import sys
import os
import math
import shutil
import subprocess
import contextlib
import unicodedata
import urllib.request
import zipfile

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

with silence_stderr():
    import fontforge
    import psMat

# --- Configurable ---
# False = take every glyph from the donor instead of reusing the font's own twins.
REUSE_TWINS = True

DONOR_URL = ("https://github.com/adobe-fonts/source-code-pro/releases/download/"
             "2.042R-u/1.062R-i/1.026R-vf/OTF-source-code-pro-2.042R-u_1.062R-i.zip")
DONOR_CACHE = os.path.expanduser("~/.cache/atkynson-cyrillic-donor")
# Upright donor masters, lightest to heaviest.
DONOR_WEIGHTS = ["ExtraLight", "Light", "Regular", "Medium", "Semibold", "Bold", "Black"]

# Donor codepoints that are never added: BOM, and emoji (leave those to the
# system colour emoji font).
SKIP_CODEPOINTS = {0xFEFF}
SKIP_FROM = 0x1F000

# Name suffix that marks glyphs added by this script.
MARK = ".patched"

# Missing codepoint -> codepoint already in the font with the same shape.
TWINS = {
    # Cyrillic
    0x0410: 0x41, 0x0412: 0x42, 0x0415: 0x45, 0x041A: 0x4B, 0x041C: 0x4D,
    0x041D: 0x48, 0x041E: 0x4F, 0x0420: 0x50, 0x0421: 0x43, 0x0422: 0x54,
    0x0425: 0x58,
    0x0430: 0x61, 0x0435: 0x65, 0x043E: 0x6F, 0x0440: 0x70, 0x0441: 0x63,
    0x0443: 0x79, 0x0445: 0x78,
    0x0401: 0xCB, 0x0451: 0xEB,  # Ё ё
    0x0405: 0x53, 0x0455: 0x73,  # Ѕ ѕ
    0x0406: 0x49, 0x0456: 0x69,  # І і
    0x0407: 0xCF, 0x0457: 0xEF,  # Ї ї
    0x0408: 0x4A, 0x0458: 0x6A,  # Ј ј
    0x04AE: 0x59,                # Ү
    0x04BB: 0x68,                # һ
    0x04C0: 0x49,                # Ӏ
    0x04D0: 0x102, 0x04D1: 0x103,  # Ӑ ӑ
    0x04D2: 0xC4, 0x04D3: 0xE4,  # Ӓ ӓ
    0x04E6: 0xD6, 0x04E7: 0xF6,  # Ӧ ӧ
    0x051A: 0x51, 0x051B: 0x71,  # Ԛ ԛ
    0x051C: 0x57, 0x051D: 0x77,  # Ԝ ԝ
    # Greek
    0x0391: 0x41, 0x0392: 0x42, 0x0395: 0x45, 0x0396: 0x5A, 0x0397: 0x48,
    0x0399: 0x49, 0x039A: 0x4B, 0x039C: 0x4D, 0x039D: 0x4E, 0x039F: 0x4F,
    0x03A1: 0x50, 0x03A4: 0x54, 0x03A5: 0x59, 0x03A7: 0x58,
    0x03AA: 0xCF, 0x03AB: 0x178,  # Ϊ Ϋ
    0x03BF: 0x6F,                # ο
    0x037E: 0x3B, 0x0387: 0xB7,  # Greek question mark, ano teleia
    0x00B5: 0x3BC,               # micro sign = mu
    0x2126: 0x3A9, 0x2206: 0x394,  # ohm = Omega, increment = Delta
    # Spacing accents = the font's own combining marks (already cell-centred)
    0x0060: 0x300, 0x00B4: 0x301, 0x00A8: 0x308, 0x00AF: 0x304, 0x00B8: 0x327,
    0x02C6: 0x302, 0x02C7: 0x30C, 0x02D8: 0x306, 0x02D9: 0x307, 0x02DA: 0x30A,
    0x02DB: 0x328, 0x02DC: 0x303, 0x02DD: 0x30B,
    # Punctuation
    0x2010: 0x2D, 0x2011: 0x2D, 0x00AD: 0x2D,  # hyphens
}

USER_FONTS_DIR = os.path.expanduser("~/Library/Fonts")
DEST_DIR = os.path.dirname(os.path.abspath(__file__))

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


def stem_width(font):
    """Thickness of the left stem of 'H', measured near the baseline."""
    y = font.capHeight * 0.15
    xs = []
    for contour in font[ord("H")].foreground:
        pts = list(contour)
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            if a.on_curve and b.on_curve and (a.y - y) * (b.y - y) < 0:
                xs.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
    xs.sort()
    return xs[1] - xs[0]


def codepoint_map(font):
    """codepoint -> glyph, including alternate encodings of the same glyph."""
    cmap = {}
    for g in font.glyphs():
        if g.unicode >= 0:
            cmap[g.unicode] = g
    for g in font.glyphs():
        for alt in (g.altuni or ()):
            cmap.setdefault(alt[0], g)
    return cmap


def should_slant(cp):
    """Letters, marks, digits and punctuation lean in italics; symbols stay upright."""
    return unicodedata.category(chr(cp)) not in ("Sm", "So")


def donor_path(weight):
    return os.path.join(DONOR_CACHE, "OTF", f"SourceCodePro-{weight}.otf")


def ensure_donor():
    if all(os.path.exists(donor_path(w)) for w in DONOR_WEIGHTS):
        return
    os.makedirs(DONOR_CACHE, exist_ok=True)
    archive = os.path.join(DONOR_CACHE, "source-code-pro.zip")
    print(f"Downloading Source Code Pro to {DONOR_CACHE} ...")
    urllib.request.urlretrieve(DONOR_URL, archive)
    with zipfile.ZipFile(archive) as z:
        z.extractall(DONOR_CACHE)
    os.remove(archive)


_donor_stems = {}

def donor_stems():
    if not _donor_stems:
        for w in DONOR_WEIGHTS:
            f = fontforge.open(donor_path(w))
            _donor_stems[w] = stem_width(f)
            f.close()
    return _donor_stems


def open_donor(target_stem):
    """Open a donor font interpolated so that its 'H' stem equals target_stem."""
    stems = donor_stems()
    weights = DONOR_WEIGHTS
    if target_stem <= stems[weights[0]]:
        return fontforge.open(donor_path(weights[0]))
    if target_stem >= stems[weights[-1]]:
        return fontforge.open(donor_path(weights[-1]))
    for lo, hi in zip(weights, weights[1:]):
        if stems[lo] <= target_stem <= stems[hi]:
            fraction = (target_stem - stems[lo]) / (stems[hi] - stems[lo])
            base = fontforge.open(donor_path(lo))
            mixed = base.interpolateFonts(fraction, donor_path(hi))
            base.close()
            return mixed


def set_os2_coverage_bits(font):
    """Advertise the new scripts in OS/2: Greek and Cyrillic unicode ranges
    (bits 7, 9) and codepages 1251 Cyrillic, 1253 Greek (bits 2, 3)."""
    def signed(v):
        v &= 0xFFFFFFFF
        return v - (1 << 32) if v & 0x80000000 else v
    ur = list(font.os2_unicoderanges)
    ur[0] = signed(ur[0] | (1 << 7) | (1 << 9))
    font.os2_unicoderanges = tuple(ur)
    cp = list(font.os2_codepages)
    cp[0] = signed(cp[0] | (1 << 2) | (1 << 3))
    font.os2_codepages = tuple(cp)


def patch(filename, out_dir):
    src_path = os.path.join(DEST_DIR, filename)
    dest_path = os.path.join(out_dir, filename)

    font = fontforge.open(src_path)
    width = cell_width(font)

    donor_probe = fontforge.open(donor_path("Regular"))
    x_scale = width / donor_probe[ord("H")].width
    y_scale = font.capHeight / donor_probe.capHeight
    donor_probe.close()

    # Stems get thicker by x_scale when stretched, so ask for a thinner donor.
    donor = open_donor(stem_width(font) / x_scale)
    donor_map = codepoint_map(donor)

    # Glyphs the font had before this script ever ran.
    original = {cp: g for cp, g in codepoint_map(font).items()
                if not g.glyphname.endswith(MARK)}

    scale = psMat.scale(x_scale, y_scale)
    slant = math.tan(math.radians(-font.italicangle))
    # Slant around half x-height so glyphs stay centred in the cell.
    scale_slanted = psMat.compose(scale, (1, 0, slant, 1, -slant * font.xHeight / 2, 0))

    codepoints = sorted(cp for cp in donor_map
                        if cp not in original
                        and cp not in SKIP_CODEPOINTS and cp < SKIP_FROM)

    reused = 0
    for cp in codepoints:
        twin = original.get(TWINS.get(cp)) if REUSE_TWINS else None
        glyph = font.createChar(cp, f"uni{cp:04X}{MARK}")
        glyph.clear()
        pen = glyph.glyphPen()
        if twin is not None:
            twin.draw(pen)
            pen = None
            reused += 1
        else:
            source = donor_map[cp]
            source.unlinkRef()
            source.draw(pen)
            pen = None
            glyph.transform(scale_slanted if should_slant(cp) else scale)
            glyph.removeOverlap()
            glyph.round()
            glyph.autoHint()
        glyph.width = width

    donor.close()
    set_os2_coverage_bits(font)
    font.generate(dest_path)
    font.close()
    print(f"Patched: {filename} ({len(codepoints)} glyphs added, {reused} reused from the font itself)")
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

    print("\nRefreshing Fontconfig cache...")
    try:
        subprocess.run(["fc-cache"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Note: Could not refresh fontconfig cache via fc-cache ({e}).")

    print("\nDone! Please restart your terminal (⌘Q) to see the updated font.")


if __name__ == "__main__":
    args = sys.argv[1:]
    out_dir = DEST_DIR
    if "--out" in args:
        i = args.index("--out")
        out_dir = os.path.abspath(args[i + 1])
        del args[i:i + 2]
        os.makedirs(out_dir, exist_ok=True)

    if args and args[0] == "single":
        print("Patching ONLY Mono-Regular for fast testing...")
        filenames = ["AtkynsonMonoNerdFontMono-Regular.otf"]
    else:
        print("Patching all 24 fonts (this will take a couple of minutes)...")
        print("Tip: Run with 'single' to test just Mono-Regular.")
        filenames = sorted(n for n in os.listdir(DEST_DIR) if n.endswith(".otf"))

    ensure_donor()

    patched = []
    with silence_stderr():
        for name in filenames:
            if patch(name, out_dir):
                patched.append(name)

    if patched and out_dir == DEST_DIR:
        install_and_cache(patched)
