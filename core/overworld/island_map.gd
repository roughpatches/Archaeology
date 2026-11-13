extends RefCounted
## The island around camp, hand-laid for the gray-box (D37). One character per 16 px tile.
##
## "#" jungle and "~" sea block the way; "." grass and "," sand are open; "o" is a fallen
## stone. Things you can use: "T" tent (rest), "W" workbench (craft), "P" Professor Philius,
## "E" the tomb entrance. Plants to gather: "f" vine fiber, "w" hardwood, "r" resin,
## "u" wild fruit, "g" glowcap. "@" is where you start. The supply boat (D42) moors at "B" at
## the end of the jetty "=", with its trader standing at "V" and any collector at "C".

const LAYOUT: Array[String] = [
	"##################################################",
	"##################################################",
	"########################E#########################",
	"#######################...########################",
	"#########o###########.......#########o############",
	"######g..........r...........u.........g##########",
	"######.####.####...##########...###.###..#########",
	"#####..####.####.#############..###.####..########",
	"####w..####..f...##############.....####.r########",
	"####...#####....###############..g...........#####",
	"#####...######..###########o###..####.######..####",
	"######...######.......##########.####..#####u..###",
	"#######....######.....f########...#####..####..###",
	"#########.....####.....#######...######...###..###",
	"##########w.....###......####.....u####....##.f###",
	"############.......#.......#.........##.....#..###",
	"#############..g.................w.......f.......#",
	"##############......................r...........##",
	"##o#######........................................",
	",,,,,,,,,,,,,.........T..W.....P..............,,,,",
	",,,,,,,,,,,,,,,,,,,,......................,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,@,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,V,,,C,,,,,,,,,,,,,,",
	"~~~~~~,,,,,,,,,,,,,,,,,,,,,,,,,,,=,,,,,,,,,,~~~~~~",
	"~~~~~~~~~~~~~,,,,,,,,,,,,,,,,,,,,=,,,,,,~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~B~~~~~~~~~~~~~~~~",
]
const THINGS := {
	"T": "tent",
	"W": "bench",
	"P": "philius",
	"E": "tomb",
	"f": "fiber",
	"w": "wood",
	"r": "resin",
	"u": "fruit",
	"g": "glowcap",
	"V": "trader",
	"C": "collector",
	"B": "boat",
}
const OPEN := ".,@VC="


static func size() -> Vector2i:
	return Vector2i(LAYOUT[0].length(), LAYOUT.size())


static func char_at(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.y >= LAYOUT.size() or p.x >= LAYOUT[p.y].length():
		return "#"
	return LAYOUT[p.y][p.x]


static func walkable(p: Vector2i) -> bool:
	return OPEN.contains(char_at(p))


static func start() -> Vector2i:
	for y in LAYOUT.size():
		var x := LAYOUT[y].find("@")
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i.ZERO


## Every usable thing: {id: "kind@x,y", kind, pos}. Plants use their forage kind.
static func things() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var c := LAYOUT[y][x]
			if THINGS.has(c):
				var kind: String = THINGS[c]
				out.append({"id": "%s@%d,%d" % [kind, x, y], "kind": kind, "pos": Vector2i(x, y)})
	return out
