"""Builds the Rent A Ride logo SVGs.

Run: python3 brand/tools/build_logo.py   (needs `pip install fonttools`)
Wordmark text is converted to outlines from the bundled Poppins fonts, so the
SVGs render identically everywhere without the font installed.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "packages/rar_design_system/assets/fonts"
OUT = ROOT / "brand"

NAVY, ROYAL, CYAN, WHITE = "#061B49", "#0866FF", "#00C8FF", "#FFFFFF"
ROYAL_ON_DARK = "#2F86FF"

# ── The "R" mark, drawn on a 512 grid, italicised by a skew ──────────────
R_PATH = (
    "M168 104H304C376 104 420 146 420 206C420 256 390 292 342 304"
    "L424 408H340L266 310H238V408H168Z"
    "M238 162H298C330 162 348 180 348 206C348 232 330 250 298 250H238Z"
)
SKEW = 'transform="translate(46 0) skewX(-10)"'
# Speed stripes (x, y, width) — motion trailing off to the left.
STRIPES = [(98, 146, 52), (58, 211, 92), (104, 276, 46)]


def mark_group(r_color: str, lane_color: str, uid: str) -> str:
    stripes = "".join(
        f'<rect x="{x}" y="{y}" width="{w}" height="30" rx="15" fill="url(#st{uid})"/>'
        for x, y, w in STRIPES
    )
    return f"""
  <defs>
    <linearGradient id="st{uid}" x1="40" y1="0" x2="150" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.35"/>
      <stop offset="0.45" stop-color="{CYAN}"/>
      <stop offset="1" stop-color="{ROYAL}"/>
    </linearGradient>
  </defs>
  <g {SKEW}>
    {stripes}
    <path d="{R_PATH}" fill="{r_color}" fill-rule="evenodd"/>
    <path d="M303 316L382 404" stroke="{lane_color}" stroke-width="7"
          stroke-linecap="round" stroke-dasharray="14 13"/>
  </g>"""


def svg(w, h, body, extra_defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}">{extra_defs}{body}\n</svg>\n')


# ── Text → outlines ───────────────────────────────────────────────────────
_fonts = {}


def text_path(text, weight, size, x, y, tracking=0.0):
    """Returns (svg path d, advance width) for text in Poppins."""
    name = {500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold"}.get(weight, "Regular")
    font = _fonts.setdefault(name, TTFont(FONTS / f"Poppins-{name}.ttf"))
    gs, cmap = font.getGlyphSet(), font.getBestCmap()
    upm = font["head"].unitsPerEm
    s = size / upm
    pen = SVGPathPen(gs)
    cx = x
    for ch in text:
        g = cmap.get(ord(ch))
        if g is None:
            continue
        gs[g].draw(TransformPen(pen, (s, 0, 0, -s, cx, y)))
        cx += font["hmtx"][g][0] * s + tracking * size
    return pen.getCommands(), cx - x - (tracking * size if text else 0)


def wordmark(x, y, size, base, accent):
    d1, w1 = text_path("Rent A ", 700, size, x, y, -0.01)
    d2, w2 = text_path("Ride", 700, size, x + w1, y, -0.01)
    return (f'<path d="{d1}" fill="{base}"/><path d="{d2}" fill="{accent}"/>', w1 + w2)


TAGLINE = "YOUR RIDE. YOUR DESTINATION. YOUR CHOICE."

files = {}

# 1. Mark only (transparent background)
files["rar_mark_white.svg"] = svg(512, 512, mark_group(WHITE, NAVY, "w"))
files["rar_mark_navy.svg"] = svg(512, 512, mark_group(NAVY, WHITE, "n"))

# 2. App icon tile
tile_defs = f"""
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="512" y2="512" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#0E3A9E"/><stop offset="0.55" stop-color="{NAVY}"/>
      <stop offset="1" stop-color="#03113A"/>
    </linearGradient>
    <radialGradient id="glow" cx="430" cy="70" r="300" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.35"/>
      <stop offset="1" stop-color="{CYAN}" stop-opacity="0"/>
    </radialGradient>
  </defs>"""
tile_bg = '<rect width="512" height="512" rx="112" fill="url(#bg)"/><rect width="512" height="512" rx="112" fill="url(#glow)"/>'
files["rar_app_icon.svg"] = svg(512, 512, tile_bg + f'<g transform="translate(36 36) scale(0.86)">{mark_group(WHITE, NAVY, "a")}</g>', tile_defs)
# Full-bleed square (no rounded corners) — the OS applies its own mask.
files["rar_app_icon_square.svg"] = svg(512, 512, tile_bg.replace('rx="112"', '') + f'<g transform="translate(46 46) scale(0.82)">{mark_group(WHITE, NAVY, "a")}</g>', tile_defs)
# Android adaptive-icon foreground: mark inside the 66 % safe zone.
files["rar_adaptive_foreground.svg"] = svg(512, 512, f'<g transform="translate(96 96) scale(0.625)">{mark_group(WHITE, NAVY, "f")}</g>')


# 3. Horizontal lockups
def horizontal(dark: bool):
    base, accent = (WHITE, ROYAL_ON_DARK) if dark else (NAVY, ROYAL)
    tag = "#B8C7EA" if dark else "#51608A"
    mark = f'<g transform="translate(-22 -6) scale(0.36)">{mark_group(base, NAVY if dark else WHITE, "h")}</g>'
    wm, ww = wordmark(164, 102, 84, base, accent)
    tg, tw = text_path(TAGLINE, 500, 17.5, 168, 140, 0.12)
    w = int(max(164 + ww, 168 + tw)) + 12
    bg = f'<rect width="{w}" height="168" fill="{NAVY}"/>' if dark else ""
    return svg(w, 168, bg + mark + wm + f'<path d="{tg}" fill="{tag}"/>')


files["rar_logo_horizontal_on_dark.svg"] = horizontal(True)
files["rar_logo_horizontal_on_light.svg"] = horizontal(False)

# 4. Alternative concept: location pin with the R in negative space
pin_defs = f"""
  <defs>
    <linearGradient id="pin" x1="120" y1="40" x2="400" y2="470" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{CYAN}"/><stop offset="1" stop-color="{ROYAL}"/>
    </linearGradient>
  </defs>"""
pin = ('<path d="M256 470C256 470 96 318 96 214C96 126 168 54 256 54'
       'C344 54 416 126 416 214C416 318 256 470 256 470Z" fill="url(#pin)"/>')
files["concept_pin_mark.svg"] = svg(512, 512, pin + f'<g transform="translate(118 74) scale(0.56)"><g {SKEW}><path d="{R_PATH}" fill="{WHITE}" fill-rule="evenodd"/></g></g>', pin_defs)

for name, content in files.items():
    (OUT / name).write_text(content)
    print("wrote", name)
