"""Placeholder pixel art made by code (D49), sized to RENDERING_CONTRACT.md.

Writes PNGs to art/placeholder/ and, with --mockup DIR, two sample screens (the camp and a tomb
chamber) at the game's 1440 x 810 window size. Deterministic: the same run makes the same art.
Stand-in only, until real art from ART_GUIDE.md replaces it.

    python3 tools/placeholder_art.py [--mockup OUT_DIR]
"""

import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "placeholder"
T = 16
OUTLINE = (5, 5, 4)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    """Lighter (f > 0) or darker (f < 0) by a fraction."""
    r, g, b, a = c
    if f >= 0:
        return (int(r + (255 - r) * f), int(g + (255 - g) * f), int(b + (255 - b) * f), a)
    return (int(r * (1 + f)), int(g * (1 + f)), int(b * (1 + f)), a)


P = {
    "unseen": hexc("050504"),
    "wall": hexc("1f2a1e"),
    "pillar": hexc("3b4a33"),
    "floor": hexc("6f6a52"),
    "ledge": hexc("a59a70"),
    "rubble": hexc("54493c"),
    "water": hexc("2f6f8f"),
    "root": hexc("3f6b2e"),
    "grass": [hexc("a39a55"), hexc("4f8a3c"), hexc("6aa84f"), hexc("6b8270")],
    "jungle": [hexc("4d5a2c"), hexc("1f4a22"), hexc("2a5a26"), hexc("344a3c")],
    "sand": hexc("d9c38c"),
    "sea": hexc("2c5d8a"),
    "jetty": hexc("8a6a44"),
    "player": hexc("4aa3ff"),
    "rope": hexc("5fd35f"),
    "shaft": hexc("fff3a8"),
    "stairs": hexc("b07cff"),
    "spot": hexc("ff9a3c"),
    "node": hexc("5ff0e6"),
    "creature": hexc("e8433a"),
    "spring": hexc("7fd4ff"),
    "philius": hexc("9a6fd1"),
    "tent": hexc("c8763a"),
    "wood": hexc("8a5a32"),
    "skin": hexc("e0b088"),
    "hat": hexc("b08850"),
    "cloth": hexc("efe6d0"),
    "trouser": hexc("5a4632"),
}


def img(w=T, h=T):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= xx < im.width and 0 <= yy < im.height:
                im.putpixel((xx, yy), c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def disc(im, cx, cy, r, c):
    for yy in range(int(cy - r - 1), int(cy + r + 2)):
        for xx in range(int(cx - r - 1), int(cx + r + 2)):
            if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r:
                px(im, xx, yy, c)


def outline(im):
    """A 1 px dark outline around everything opaque (contract: props and characters)."""
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if im.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and im.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), OUTLINE + (255,))
                        break
    return out


def speckle(im, rng, base, n, spread=0.12):
    for _ in range(n):
        x, y = rng.randrange(im.width), rng.randrange(im.height)
        px(im, x, y, shade(base, rng.choice([-spread, spread, -spread / 2])))


# ---- ground tiles -------------------------------------------------------------------------


def grass(season, seed):
    rng = random.Random(seed)
    base = P["grass"][season]
    im = img()
    rect(im, 0, 0, T, T, base)
    speckle(im, rng, base, 18)
    for _ in range(3):  # flat tufts: no height (contract section 2)
        x, y = rng.randrange(1, 15), rng.randrange(2, 15)
        px(im, x, y, shade(base, 0.22))
        px(im, x - 1, y + 1, shade(base, 0.12))
        px(im, x + 1, y + 1, shade(base, 0.12))
    return im


def jungle(season, seed, face):
    """Jungle wall seen from above; with face, the front of the foliage shows (open tile below)."""
    rng = random.Random(seed)
    base = P["jungle"][season]
    im = img()
    rect(im, 0, 0, T, T, shade(base, -0.25))
    for _ in range(7):
        disc(im, rng.randrange(0, 16), rng.randrange(0, 12 if face else 16), rng.choice([3, 4]),
             shade(base, rng.choice([0.0, 0.08, -0.08])))
    for _ in range(10):
        px(im, rng.randrange(16), rng.randrange(16), shade(base, 0.25))
    if face:
        rect(im, 0, 11, T, 5, shade(base, -0.45))
        for x in range(0, 16, 3):
            rect(im, x, 11, 1, rng.randrange(2, 5), shade(base, -0.15))
        rect(im, 0, 15, T, 1, shade(base, -0.65))
    return im


def sand(seed):
    rng = random.Random(seed)
    im = img()
    rect(im, 0, 0, T, T, P["sand"])
    speckle(im, rng, P["sand"], 14, 0.08)
    return im


def sea(seed, frame=0):
    rng = random.Random(seed)
    im = img()
    rect(im, 0, 0, T, T, P["sea"])
    for i in range(3):
        y = (rng.randrange(16) + frame * 2) % 16
        x = rng.randrange(12)
        rect(im, x, y, rng.randrange(3, 5), 1, shade(P["sea"], 0.25))
    return im


def jetty():
    im = img()
    rect(im, 0, 0, T, T, P["sea"])
    rect(im, 2, 0, 12, T, P["jetty"])
    for y in (3, 7, 11, 15):
        rect(im, 2, y, 12, 1, shade(P["jetty"], -0.35))
    rect(im, 2, 0, 1, T, shade(P["jetty"], -0.2))
    return im


def tomb_floor(seed):
    rng = random.Random(seed)
    im = img()
    rect(im, 0, 0, T, T, P["floor"])
    # Worn slabs: 8 x 8 with dark seams, offset by row.
    off = rng.choice([0, 4])
    for y in (0, 8):
        rect(im, 0, y, T, 1, shade(P["floor"], -0.3))
    for x in (off, off + 8):
        rect(im, x % 16, 0, 1, 8, shade(P["floor"], -0.3))
        rect(im, (x + 4) % 16, 8, 1, 8, shade(P["floor"], -0.3))
    speckle(im, rng, P["floor"], 12, 0.1)
    if rng.random() < 0.25:  # a flat root across the floor
        y = rng.randrange(3, 13)
        for x in range(rng.randrange(0, 6), rng.randrange(10, 16)):
            px(im, x, y + (x // 4) % 2, P["root"])
    return im


def tomb_wall(seed, face):
    rng = random.Random(seed)
    im = img()
    rect(im, 0, 0, T, T, P["wall"])
    speckle(im, rng, P["wall"], 16, 0.25)
    for _ in range(2):  # moss
        disc(im, rng.randrange(16), rng.randrange(10), 2, shade(P["root"], -0.3))
    if face:
        # Carved block face where the floor is below: courses of stone.
        rect(im, 0, 8, T, 8, shade(P["pillar"], -0.1))
        rect(im, 0, 8, T, 1, shade(P["pillar"], 0.25))
        rect(im, 0, 12, T, 1, shade(P["pillar"], -0.4))
        for x in (3, 11):
            rect(im, x, 8, 1, 4, shade(P["pillar"], -0.4))
        rect(im, 7, 12, 1, 4, shade(P["pillar"], -0.4))
        rect(im, 0, 15, T, 1, OUTLINE + (255,))
    return im


def pillar():
    im = tomb_floor(77)
    rect(im, 3, 0, 10, 15, P["pillar"])
    rect(im, 3, 0, 10, 2, shade(P["pillar"], 0.3))
    rect(im, 4, 3, 1, 11, shade(P["pillar"], 0.15))
    rect(im, 11, 3, 1, 11, shade(P["pillar"], -0.3))
    rect(im, 6, 6, 4, 3, shade(P["pillar"], -0.35))  # carved glyph
    rect(im, 3, 14, 10, 1, OUTLINE + (255,))
    return im


def ledge():
    im = tomb_floor(31)
    rect(im, 11, 0, 5, T, P["ledge"])
    rect(im, 11, 0, 1, T, shade(P["ledge"], 0.25))
    rect(im, 14, 0, 2, T, shade(P["ledge"], -0.55))  # the drop, on the right (D31)
    for y in range(1, 16, 4):
        px(im, 13, y, shade(P["ledge"], -0.3))
    return im


def rubble(seed):
    rng = random.Random(seed)
    im = tomb_floor(seed + 1)
    for _ in range(5):
        cx, cy, r = rng.randrange(3, 13), rng.randrange(4, 13), rng.choice([2, 2, 3])
        disc(im, cx, cy, r, P["rubble"])
        px(im, cx - 1, cy - 1, shade(P["rubble"], 0.3))
    return im


def stream(seed, frame=0):
    rng = random.Random(seed)
    im = img()
    rect(im, 0, 0, T, T, P["water"])
    for _ in range(4):
        y = rng.randrange(16)
        x = (rng.randrange(16) + frame * 3) % 16
        rect(im, x, y, 3, 1, shade(P["water"], 0.35))
    rect(im, 0, 0, 1, T, shade(P["water"], -0.3))
    rect(im, 15, 0, 1, T, shade(P["water"], -0.3))
    return im


# ---- props and markers --------------------------------------------------------------------


def tent():
    im = img(16, 32)
    c = P["tent"]
    for y in range(10, 31):
        half = (y - 10) * 7 // 20 + 1
        rect(im, 8 - half, y, half * 2, 1, c if y < 28 else shade(c, -0.2))
        px(im, 8 - half, y, shade(c, 0.2))
    rect(im, 6, 22, 4, 9, shade(c, -0.6))  # door
    rect(im, 7, 9, 2, 2, P["wood"])  # pole
    return outline(im)


def bench():
    im = img()
    rect(im, 1, 5, 14, 4, P["wood"])
    rect(im, 1, 5, 14, 1, shade(P["wood"], 0.3))
    rect(im, 2, 9, 2, 5, shade(P["wood"], -0.3))
    rect(im, 12, 9, 2, 5, shade(P["wood"], -0.3))
    rect(im, 4, 3, 4, 2, hexc("9a9a9a"))  # a saw
    rect(im, 10, 3, 2, 2, hexc("c04030"))  # a mallet
    return outline(im)


def shelf(n=0):
    im = img()
    rect(im, 1, 1, 14, 14, shade(P["wood"], 0.1))
    rect(im, 2, 2, 12, 12, shade(P["wood"], -0.35))
    rect(im, 2, 7, 12, 1, P["wood"])
    gems = [P["node"], hexc("4fa860"), hexc("ffd84a"), hexc("d8cfc0"), hexc("c87a50")]
    for k in range(n):
        x, y = 3 + (k % 3) * 4, 4 if k < 3 else 10
        rect(im, x, y, 2, 3, gems[k])
    return outline(im)


def plans():
    im = img()
    rect(im, 3, 12, 1, 4, P["wood"])
    rect(im, 12, 12, 1, 4, P["wood"])
    rect(im, 2, 2, 12, 10, P["cloth"])
    for y in (4, 6, 8):
        rect(im, 4, y, 8, 1, hexc("6a8ab0"))
    rect(im, 9, 5, 3, 3, hexc("6a8ab0"))
    return outline(im)


def tomb_door():
    im = img(16, 32)
    stone = hexc("8f8a70")
    rect(im, 1, 8, 14, 23, stone)
    rect(im, 1, 8, 14, 2, shade(stone, 0.25))
    rect(im, 4, 13, 8, 18, P["unseen"])
    rect(im, 3, 11, 10, 2, shade(stone, -0.3))  # lintel
    for x, y in ((1, 12), (2, 15), (13, 10), (14, 18), (12, 24), (2, 26)):
        rect(im, x, y, 1, 3, P["root"])
    return outline(im)


def plant(kind, ready=True):
    im = img()
    colors = {
        "fiber": hexc("8fd16a"),
        "wood": hexc("a0703c"),
        "resin": hexc("f0b43c"),
        "fruit": hexc("e8504a"),
        "glowcap": hexc("7ff0ff"),
    }
    leaf = hexc("3f7a2e")
    if kind == "wood":
        rect(im, 7, 6, 2, 9, P["wood"])
        disc(im, 8, 5, 4, leaf)
    elif kind == "glowcap":
        for x, y in ((5, 10), (10, 8), (8, 12)):
            rect(im, x, y, 1, 3, P["cloth"])
            if ready:
                rect(im, x - 1, y - 1, 3, 2, colors[kind])
    else:
        disc(im, 8, 9, 5, leaf)
        disc(im, 7, 8, 2, shade(leaf, 0.2))
    if ready and kind != "glowcap":
        for x, y in ((5, 7), (10, 9), (8, 12)):
            rect(im, x, y, 2, 2, colors[kind])
    return outline(im)


def boat():
    im = img(48, 32)
    hull = hexc("6b4a2a")
    for y in range(20, 30):
        inset = max(0, y - 25)
        rect(im, 2 + inset, y, 44 - inset * 2, 1, hull if y > 21 else shade(hull, 0.3))
    rect(im, 23, 2, 2, 19, P["wood"])
    for y in range(3, 19):
        rect(im, 25, y, (y - 2) * 12 // 16, 1, P["cloth"])
    return outline(im)


def marker(kind):
    im = img()
    if kind == "rope":
        for y in range(0, 14):
            px(im, 7 + (y // 3) % 2, y, P["rope"])
            px(im, 8 + (y // 3) % 2, y, shade(P["rope"], -0.3))
        rect(im, 5, 13, 6, 2, shade(P["rope"], -0.2))
    elif kind == "anchor":
        rect(im, 7, 4, 2, 10, hexc("9a9a9a"))
        rect(im, 6, 4, 4, 1, hexc("c8c8c8"))
        for y in range(5, 14):
            px(im, 9 + (y // 2) % 2, y, P["rope"])
    elif kind == "stairs":
        for k in range(4):
            rect(im, 2 + k, 2 + k * 3, 12 - k * 2, 3, shade(P["stairs"], -0.15 * k))
        rect(im, 6, 13, 4, 2, P["unseen"])
    elif kind == "shaft":
        for y in range(16):
            for x in range(4, 12):
                if (x + y) % 2 == 0:
                    px(im, x, y, P["shaft"][:3] + (110,))
        rect(im, 6, 0, 4, 16, P["shaft"][:3] + (60,))
        return im
    return outline(im)


def dig_spot(state):
    im = img()
    soil = hexc("7a583a")
    if state == "done":
        rect(im, 3, 6, 10, 6, shade(soil, -0.4))
        rect(im, 3, 6, 10, 1, OUTLINE + (255,))
        return im
    # Flat disturbed earth, wider than tall so it reads as ground, not a rock.
    for y in range(6, 13):
        half = 6 - abs(y - 9) * 2 // 3
        rect(im, 8 - half, y, half * 2, 1, soil if y > 7 else shade(soil, 0.15))
    for x, y in ((4, 9), (7, 11), (11, 8), (6, 7)):
        px(im, x, y, shade(soil, -0.35))
    rect(im, 9, 8, 2, 2, hexc("d8cfc0"))  # a shard showing
    if state == "mapped":
        for x, y in ((2, 3), (13, 3), (2, 14), (13, 14)):
            rect(im, x, y, 1, 2, hexc("ffd84a"))
    return outline(im)


def crystal():
    im = img()
    rect(im, 3, 11, 10, 3, P["pillar"])
    for x, h in ((5, 6), (8, 9), (11, 5)):
        rect(im, x - 1, 11 - h, 3, h, P["node"])
        rect(im, x - 1, 11 - h, 1, h, shade(P["node"], 0.4))
    return outline(im)


def spring():
    im = img()
    disc(im, 8, 9, 5, hexc("4a5a4a"))
    disc(im, 8, 9, 4, P["spring"])
    px(im, 6, 8, shade(P["spring"], 0.6))
    px(im, 10, 10, shade(P["spring"], 0.5))
    return outline(im)


# ---- characters (32 x 32, feet at 16, 30) -------------------------------------------------


def person(coat, hat=None, hair=None, extra=None):
    im = img(32, 32)
    rect(im, 12, 26, 3, 4, P["trouser"])  # legs
    rect(im, 17, 26, 3, 4, P["trouser"])
    rect(im, 11, 17, 10, 10, coat)  # body
    rect(im, 11, 17, 10, 1, shade(coat, 0.25))
    rect(im, 9, 18, 2, 7, coat)  # arms
    rect(im, 21, 18, 2, 7, coat)
    rect(im, 9, 25, 2, 1, P["skin"])
    rect(im, 21, 25, 2, 1, P["skin"])
    rect(im, 12, 9, 8, 8, P["skin"])  # head
    px(im, 14, 13, OUTLINE + (255,))
    px(im, 17, 13, OUTLINE + (255,))
    if hair:
        rect(im, 11, 8, 10, 3, hair)
        rect(im, 11, 8, 2, 6, hair)
        rect(im, 19, 8, 2, 6, hair)
    if hat:
        rect(im, 9, 8, 14, 2, hat)
        rect(im, 12, 5, 8, 3, hat)
        rect(im, 12, 7, 8, 1, shade(hat, -0.3))
    if extra:
        extra(im)
    return outline(im)


def player():
    def satchel(im):
        rect(im, 19, 19, 4, 5, P["wood"])
        for k in range(8):
            px(im, 12 + k, 17 + k // 2 + 1, P["wood"])

    return person(P["player"], hat=P["hat"], extra=satchel)


def philius():
    def specs(im):
        rect(im, 13, 12, 3, 2, hexc("c8c8c8"))
        rect(im, 16, 12, 3, 2, hexc("c8c8c8"))
        rect(im, 14, 15, 4, 2, hexc("efefef"))  # moustache

    return person(P["philius"], hair=hexc("efefef"), extra=specs)


def creature(state="normal"):
    im = img(32, 32)
    body = P["creature"] if state != "stunned" else shade(P["creature"], -0.45)
    if state == "stunned":
        rect(im, 8, 23, 16, 5, body)
        rect(im, 22, 22, 4, 4, body)
        for x in (11, 15, 19):
            px(im, x, 21, hexc("ffd84a"))
        return outline(im)
    rect(im, 10, 18, 12, 9, body)  # body
    rect(im, 11, 12, 10, 8, body)  # head
    rect(im, 11, 10, 2, 3, body)  # ears
    rect(im, 19, 10, 2, 3, body)
    for x in (11, 15, 19):
        rect(im, x, 20, 2, 1, shade(body, -0.4))  # stripes
    rect(im, 11, 27, 3, 2, shade(body, -0.3))
    rect(im, 18, 27, 3, 2, shade(body, -0.3))
    if state == "flee":
        rect(im, 22, 17, 5, 2, body)  # tail up, facing away
    else:
        px(im, 13, 15, hexc("ffd84a"))
        px(im, 18, 15, hexc("ffd84a"))
        rect(im, 21, 22, 6, 2, body)
    return outline(im)


# ---- writing ------------------------------------------------------------------------------


def all_assets():
    a = {}
    for s, name in enumerate(["dry", "rains", "bloom", "mists"]):
        a["island/grass_%s" % name] = grass(s, 1)
        a["island/jungle_%s" % name] = jungle(s, 2, False)
        a["island/jungle_face_%s" % name] = jungle(s, 3, True)
    a["island/sand"] = sand(4)
    for f in range(4):
        a["island/sea_%d" % f] = sea(5, f)
        a["tomb/stream_%d" % f] = stream(6, f)
    a["island/jetty"] = jetty()
    a["tomb/floor"] = tomb_floor(7)
    a["tomb/wall"] = tomb_wall(8, False)
    a["tomb/wall_face"] = tomb_wall(9, True)
    a["tomb/pillar"] = pillar()
    a["tomb/ledge"] = ledge()
    a["tomb/rubble"] = rubble(10)
    for k in ("rope", "anchor", "stairs", "shaft"):
        a["tomb/" + k] = marker(k)
    for s in ("sign", "mapped", "done"):
        a["tomb/dig_spot_" + s] = dig_spot(s)
    a["tomb/crystal"] = crystal()
    a["tomb/spring"] = spring()
    a["camp/tent"] = tent()
    a["camp/bench"] = bench()
    a["camp/shelf"] = shelf(3)
    a["camp/plans"] = plans()
    a["camp/tomb_door"] = tomb_door()
    a["camp/boat"] = boat()
    for k in ("fiber", "wood", "resin", "fruit", "glowcap"):
        a["plants/%s" % k] = plant(k)
        a["plants/%s_picked" % k] = plant(k, False)
    a["characters/player"] = player()
    a["characters/philius"] = philius()
    for s in ("normal", "flee", "stunned"):
        a["characters/creature_" + s] = creature(s)
    return a


def write(assets):
    for name, im in assets.items():
        path = OUT / (name + ".png")
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)


if __name__ == "__main__":
    ASSETS = all_assets()
    write(ASSETS)
    print("wrote %d images to %s" % (len(ASSETS), OUT))
    if "--mockup" in sys.argv:
        from placeholder_mockup import mockups

        mockups(ASSETS, Path(sys.argv[sys.argv.index("--mockup") + 1]))
