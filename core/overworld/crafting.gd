extends RefCounted
## Gear made at the camp workbench from what you gather (D39). Gear goes into the pack you
## take on expeditions.

const Forage := preload("res://core/overworld/forage.gd")

const RECIPES := {
	"anchor": {"fiber": 2, "wood": 1},
	"flare": {"resin": 1, "fiber": 1},
	"ration": {"fruit": 1, "glowcap": 1},
}
const NAMES := {"anchor": "Rope anchor", "flare": "Flare", "ration": "Trail ration"}
const ORDER: Array[String] = ["anchor", "flare", "ration"]
## Most of each piece of gear you can carry.
const PACK_CAP := 3


## "" if the item can be made from this inventory and gear, else why not.
static func why_not(item: String, inventory: Dictionary, gear: Dictionary) -> String:
	if int(gear.get(item, 0)) >= PACK_CAP:
		return "You can't carry more than %d." % PACK_CAP
	var recipe: Dictionary = RECIPES[item]
	for res: String in recipe:
		if int(inventory.get(res, 0)) < int(recipe[res]):
			return "Needs %s." % describe(item)
	return ""


## Makes one, changing inventory and gear in place. Returns false if it can't.
static func craft(item: String, inventory: Dictionary, gear: Dictionary) -> bool:
	if why_not(item, inventory, gear) != "":
		return false
	var recipe: Dictionary = RECIPES[item]
	for res: String in recipe:
		inventory[res] = int(inventory[res]) - int(recipe[res])
	gear[item] = int(gear.get(item, 0)) + 1
	return true


## e.g. "2 Vine fiber + 1 Hardwood"
static func describe(item: String) -> String:
	var parts: Array[String] = []
	var recipe: Dictionary = RECIPES[item]
	for res: String in recipe:
		parts.append("%d %s" % [recipe[res], Forage.display_name(res)])
	return " + ".join(parts)
