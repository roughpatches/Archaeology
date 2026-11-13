extends RefCounted
## The supply boat (D42): it calls every 1 to 3 days, stays that day and night, and brings one
## trader and sometimes a museum collector. Who comes is seeded from the world, so the same game
## always gets the same visitors.

const SeededRng := preload("res://core/seeded_rng.gd")
const Finds := preload("res://core/finds.gd")

const FIRST_CALL := 2
const MIN_GAP := 1
const MAX_GAP := 3
const COLLECTOR_CHANCE := 0.6

## Traders (D42): what each is keen on pays LIKED_RATE, anything else OTHER_RATE.
## likes: rarities, collection ids, or "material".
const TRADERS := {
	"mira": {"name": "Mira, a trinket dealer", "likes": ["common"]},
	"dace": {"name": "Dace, an antiquities broker", "likes": ["uncommon", "rare"]},
	"tamsin": {"name": "Old Tamsin, who buys folk goods", "likes": ["hearth"]},
	"corvin": {"name": "Corvin, a jeweller", "likes": ["jade", "material"]},
	"brask": {"name": "Brask, an outfitter", "likes": ["material"], "sells": true},
}
const LIKED_RATE := 1.5
const OTHER_RATE := 0.6
const CRYSTAL_PRICE := 6

## What the outfitter sells, and for how much.
const GEAR_PRICES := {"anchor": 20, "flare": 12, "ration": 15}

## Museum collectors (D43): each wants one collection.
const COLLECTORS := {
	"varga": {"name": "Dr. Ilse Varga of the Hollowmere Museum", "collection": "jade"},
	"okafor": {"name": "Professor Okafor of the Lantern Institute", "collection": "hearth"},
	"sel": {"name": "Sel Arden of the Observatory Archive", "collection": "stars"},
}
## Coin a museum grants when you complete its collection.
const COLLECTION_REWARD := 150


## Who comes on the nth call: {trader: id, collector: id or ""}.
static func visitors(world_seed: int, call: int) -> Dictionary:
	var rng := SeededRng.new(SeededRng.derive(world_seed, ["boat", call]))
	var trader: String = rng.pick(TRADERS.keys())
	var collector := ""
	if rng.chance(COLLECTOR_CHANCE):
		collector = rng.pick(COLLECTORS.keys())
	return {"trader": trader, "collector": collector}


## Days until the call after the nth.
static func gap(world_seed: int, call: int) -> int:
	var rng := SeededRng.new(SeededRng.derive(world_seed, ["boat gap", call]))
	return rng.range_int(MIN_GAP, MAX_GAP)


## Whether this trader is keen on this find.
static func likes(trader: String, find: Dictionary) -> bool:
	var keen: Array = TRADERS[trader]["likes"]
	return keen.has(find.get("rarity", "")) or keen.has(Finds.collection_of(find.get("id", "")))


## What this trader pays for a find.
static func offer(trader: String, find: Dictionary) -> int:
	var rate := LIKED_RATE if likes(trader, find) else OTHER_RATE
	return maxi(1, roundi(Finds.base_value(find) * rate))


## What this trader pays for one crystal, or 0 if they don't buy them.
static func crystal_offer(trader: String) -> int:
	return CRYSTAL_PRICE if (TRADERS[trader]["likes"] as Array).has("material") else 0


static func sells_gear(trader: String) -> bool:
	return TRADERS[trader].get("sells", false)
