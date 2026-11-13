extends RefCounted
## Camp upgrades bought with coin (D44) and the display shelf (D45). Both make the next
## expedition go better: upgrades change what you can do down there, and finds on the shelf
## teach you to read the tomb's hints.

const UPGRADES := {
	"lamp":
	{
		"name": "Brighter lamp",
		"cost": 60,
		"about": "your lamp reaches 7 tiles in the tomb, not 5",
	},
	"bag":
	{
		"name": "Bigger bag",
		"cost": 80,
		"about": "carry 12 things out of the tomb, not 8",
	},
	"cot":
	{
		"name": "Better cot",
		"cost": 100,
		"about": "stamina goes up to 125",
	},
	"rope":
	{
		"name": "Fixed rope to floor 2",
		"cost": 120,
		"about": "a rope out at the top of floor 2 as well as floor 1",
	},
}
const ORDER: Array[String] = ["lamp", "bag", "cot", "rope"]

const BASE_SIGHT := 5
const LAMP_SIGHT := 7
const BASE_BAG := 8
const BIG_BAG := 12
const BASE_STAMINA := 100
const COT_STAMINA := 125

## The display shelf holds this many finds.
const SHELF_SLOTS := 5
## Tunnel hints are right this often with nothing on the shelf (FloorGen.HINT_ACCURACY)...
const BASE_HINT := 0.65
## ...and this much more often for each find on it: Philius studies their carvings and learns
## the builders' marks.
const HINT_PER_FIND := 0.03


## "" if the upgrade can be bought, else why not.
static func why_not(id: String, built: Array, coin: int) -> String:
	if built.has(id):
		return "Already built."
	var cost: int = UPGRADES[id]["cost"]
	if coin < cost:
		return "That's %d coin; you have %d." % [cost, coin]
	return ""


static func max_stamina(built: Array) -> int:
	return COT_STAMINA if built.has("cot") else BASE_STAMINA


static func hint_accuracy(shelf_size: int) -> float:
	return BASE_HINT + HINT_PER_FIND * mini(shelf_size, SHELF_SLOTS)


## What camp does for the next expedition: lamp reach, bag size, how many floors have a rope
## out at the top, and how often tunnel hints are right.
static func expedition_boosts(built: Array, shelf_size: int) -> Dictionary:
	return {
		"sight": LAMP_SIGHT if built.has("lamp") else BASE_SIGHT,
		"bag_slots": BIG_BAG if built.has("bag") else BASE_BAG,
		"rope_floors": 2 if built.has("rope") else 1,
		"hint_accuracy": hint_accuracy(shelf_size),
	}
