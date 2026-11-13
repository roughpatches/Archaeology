extends RefCounted
## Things to gather on the island, and when they can be gathered (D36, D37).
##
## Each kind grows in some halves of the day and some seasons. Gathering a plant empties it until
## it grows back REGROW halves later. In its best season a plant gives two.

const Calendar := preload("res://core/calendar.gd")

const GATHER_COST := 2

## kind -> {name, halves: [0 day, 1 night], seasons: Calendar.SEASONS indices, best: season,
## regrow: halves}
const KINDS := {
	"fiber":
	{"name": "Vine fiber", "halves": [0, 1], "seasons": [0, 1, 2, 3], "best": 1, "regrow": 2},
	"wood":
	{"name": "Hardwood", "halves": [0, 1], "seasons": [0, 1, 2, 3], "best": -1, "regrow": 4},
	"resin": {"name": "Resin", "halves": [0], "seasons": [0, 2, 3], "best": 0, "regrow": 4},
	"fruit": {"name": "Wild fruit", "halves": [0], "seasons": [1, 2], "best": 2, "regrow": 4},
	"glowcap": {"name": "Glowcap", "halves": [1], "seasons": [1, 2, 3], "best": 3, "regrow": 2},
}


static func display_name(kind: String) -> String:
	return KINDS[kind]["name"]


## Whether a kind grows in this season and half at all.
static func in_season(kind: String, season: int, half: int) -> bool:
	var k: Dictionary = KINDS[kind]
	return (k["seasons"] as Array).has(season) and (k["halves"] as Array).has(half)


## "" if a plant can be gathered now, else why not, in words for the player.
## ready_at: the half index it has grown back by (0 if never gathered).
static func why_not(kind: String, ready_at: int, day: int, half: int) -> String:
	var k: Dictionary = KINDS[kind]
	if not (k["seasons"] as Array).has(Calendar.season(day)):
		return "%s doesn't grow in %s." % [k["name"], Calendar.SEASONS[Calendar.season(day)]]
	if not (k["halves"] as Array).has(half):
		return "%s only shows itself %s." % [k["name"], "at night" if half == 0 else "by day"]
	if Calendar.half_index(day, half) < ready_at:
		return "Picked clean. It'll grow back."
	return ""


## How many a gather gives right now.
static func yield_now(kind: String, day: int) -> int:
	return 2 if KINDS[kind]["best"] == Calendar.season(day) else 1


## The half index a plant gathered now will have grown back by.
static func regrown_at(kind: String, day: int, half: int) -> int:
	return Calendar.half_index(day, half) + int(KINDS[kind]["regrow"])
