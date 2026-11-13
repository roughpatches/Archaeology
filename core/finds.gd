extends RefCounted
## The finds of the jungle tomb (D33), what collection each belongs to, and what it's worth.
## Names are placeholders (D10).

const BY_RARITY := {
	"common": ["Jade bead", "Clay effigy", "Bone flute"],
	"uncommon": ["Obsidian blade", "Serpent idol", "Star-chart shard"],
	"rare": ["Gold-leaf mask piece", "Star-carved lintel stone"],
}
const RARITIES: Array[String] = ["common", "uncommon", "rare"]

## Museum collections (D43): id -> {name, finds}.
const COLLECTIONS := {
	"jade":
	{"name": "The Jade Court", "finds": ["Jade bead", "Serpent idol", "Gold-leaf mask piece"]},
	"hearth": {"name": "Hearth and Hunt", "finds": ["Clay effigy", "Bone flute", "Obsidian blade"]},
	"stars":
	{"name": "The Star Readers", "finds": ["Star-chart shard", "Star-carved lintel stone"]},
}

## Coin a trader pays for a pristine find of each rarity (D42).
const BASE_PRICE := {"common": 10, "uncommon": 25, "rare": 60}
## Intact finds sell for more, pieces for less (D22).
const CONDITION_PRICE := {"pristine": 1.0, "intact": 0.8, "worn": 0.45, "fragment": 0.2}


## The collection a find belongs to, or "" (finds from before collections existed).
static func collection_of(find_id: String) -> String:
	for c: String in COLLECTIONS:
		if (COLLECTIONS[c]["finds"] as Array).has(find_id):
			return c
	return ""


## Coin for a find at full interest, before a trader's own taste.
static func base_value(find: Dictionary) -> int:
	var base := float(BASE_PRICE.get(find.get("rarity", "common"), 10))
	return maxi(1, roundi(base * float(CONDITION_PRICE.get(find.get("condition", "worn"), 0.45))))


## e.g. "Serpent idol (uncommon, intact, documented)"
static func describe(find: Dictionary) -> String:
	return (
		"%s (%s, %s, %s)"
		% [
			find.get("id", "?"),
			find.get("rarity", "?"),
			find.get("condition", "?"),
			find.get("context", "?")
		]
	)
