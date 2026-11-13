"""Sample screens from the placeholder art, composed the way the game draws (contract
sections 1 to 3): a 240 x 135 world view (480 x 270 at camera zoom 2), scaled to 1440 x 810."""

import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
T = 16
VIEW = (240, 135)
SCALE = 6
THINGS = {"T": "camp/tent", "W": "camp/bench", "D": "camp/shelf_3", "K": "camp/plans",
          "E": "camp/tomb_door", "B": "camp/boat", "f": "plants/fiber", "w": "plants/wood",
          "r": "plants/resin", "u": "plants/fruit", "g": "plants/glowcap"}


def island_layout():
    src = (ROOT / "core/overworld/island_map.gd").read_text()
    start = src.index("const LAYOUT")
    block = src[start:src.index("\n]", start)]
    return re.findall(r'"([^"]{50})"', block)


def paste(canvas, im, x, y):
    canvas.alpha_composite(im, (int(x), int(y)))


def finish(world, out):
    big = world.resize((world.width * SCALE, world.height * SCALE), Image.NEAREST)
    big.convert("RGB").save(out)


def camp(a, out, season="rains"):
    rows = island_layout()
    w, h = len(rows[0]) * T, len(rows) * T
    world = Image.new("RGBA", (w, h))
    props = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            below = rows[y + 1][x] if y + 1 < len(rows) else "#"
            if ch == "#":
                key = "island/jungle_face_" if below != "#" else "island/jungle_"
                tile = a[key + season]
            elif ch in "~B":
                tile = a["island/sea_0"]
            elif ch == "=":
                tile = a["island/jetty"]
            elif ch in ",@VC":
                tile = a["island/sand"]
            else:
                tile = a["island/grass_" + season]
            paste(world, tile, x * T, y * T)
            if ch in THINGS:
                props.append((y, x, a[THINGS[ch]]))
    # Y-sorted layer: props and characters by their feet (contract section 3).
    philius = [(y, x) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "P"][0]
    props.append((philius[0], philius[1], a["characters/philius"]))
    player = (philius[0] + 2, philius[1] - 5)
    props.append((player[0], player[1], a["characters/player"]))
    for y, x, im in sorted(props, key=lambda p: p[0]):
        if im.width == 32:  # characters: feet at (16, 30) on the tile's bottom centre
            paste(world, im, x * T + 8 - 16, y * T + 16 - 31)
        elif im.width == 48:
            paste(world, im, x * T - 16, y * T + 16 - 32)
        else:
            paste(world, im, x * T, y * T + 16 - im.height)
    cx, cy = player[1] * T + 8, player[0] * T + 8
    left, top = cx - VIEW[0] // 2 - 16, cy - VIEW[1] // 2 - 24
    finish(world.crop((left, top, left + VIEW[0], top + VIEW[1])), out)


TOMB = [
    "###############################",
    "###############################",
    "##.............################",
    "##..o.......~.o################",
    "##..........~....:.............",
    "##.....R....~..o###############",
    "##.....x....~.*################",
    "##..........~..################",
    "##..o...c...~..################",
    "##..........~..################",
    "###############################",
    "###############################",
]


def tomb(a, out):
    rows = TOMB
    world = Image.new("RGBA", (len(rows[0]) * T, len(rows) * T), (5, 5, 4, 255))
    player = (5, 9)
    props = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            below = rows[y + 1][x] if y + 1 < len(rows) else "#"
            if ch == "#":
                tile = a["tomb/wall_face" if below != "#" else "tomb/wall"]
            elif ch == "o":
                tile = a["tomb/pillar"]
            elif ch == "~":
                tile = a["tomb/stream_0"]
            elif ch == ":":
                tile = a["tomb/rubble"]
            else:
                tile = a["tomb/floor"]
            paste(world, tile, x * T, y * T)
            extra = {"R": "tomb/rope", "x": "tomb/dig_spot_sign", "*": "tomb/crystal",
                     "c": "tomb/spring"}.get(ch)
            if extra:
                paste(world, a[extra], x * T, y * T)
    paste(world, a["tomb/ledge"], 30 * T, 4 * T)
    props.append((8, 5, a["characters/creature_normal"]))
    props.append((player[0], player[1], a["characters/player"]))
    for y, x, im in sorted(props, key=lambda p: p[0]):
        paste(world, im, x * T + 8 - 16, y * T + 16 - 31)
    # Lamp light (drawn by code, contract section 3): full within 4 tiles, black by 7.
    dark = Image.new("RGBA", world.size, (0, 0, 0, 0))
    for y in range(len(rows)):
        for x in range(len(rows[0])):
            d = abs(x - player[1]) + abs(y - player[0])
            alpha = int(max(0.0, min(1.0, (d - 4) / 3.0)) * 255)
            for yy in range(T):
                for xx in range(T):
                    dark.putpixel((x * T + xx, y * T + yy), (5, 5, 4, alpha))
    world.alpha_composite(dark)
    cx, cy = player[1] * T + 8, player[0] * T + 8
    left, top = cx - VIEW[0] // 2, cy - VIEW[1] // 2
    finish(world.crop((left, top, left + VIEW[0], top + VIEW[1])), out)


def sheet(a, out):
    """Every asset on one sheet at 6x, for review."""
    items = list(a.items())
    cols = 12
    cell = 34
    rows = (len(items) + cols - 1) // cols
    s = Image.new("RGBA", (cols * cell, rows * cell), (40, 40, 44, 255))
    for i, (_, im) in enumerate(items):
        x, y = (i % cols) * cell + 1, (i // cols) * cell + 1
        s.alpha_composite(im, (x + (32 - im.width) // 2, y + max(0, 32 - im.height)))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).convert("RGB").save(out)


def mockups(assets, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    camp(assets, out_dir / "art-mock-camp.png")
    tomb(assets, out_dir / "art-mock-tomb.png")
    sheet(assets, out_dir / "art-mock-sheet.png")
    print("mockups in", out_dir)
