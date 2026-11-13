extends Node
## The single owner of everything that is saved.
##
## Scenes read `data` and change it only through methods here (or core/ functions whose
## results are written back here), then the `changed` signal tells everyone to refresh.

signal changed

const Migrations := preload("res://core/save_migrations.gd")
const Calendar := preload("res://core/calendar.gd")
const Forage := preload("res://core/overworld/forage.gd")
const Crafting := preload("res://core/overworld/crafting.gd")
const Boat := preload("res://core/boat.gd")
const Finds := preload("res://core/finds.gd")

var data: Dictionary = {}
## The gear packed for the expedition under way. Not saved: it lives only for one trip.
var expedition_pack: Dictionary = {}
## Set when an expedition ends, so the overworld puts you back at the tomb entrance.
var back_from_tomb := false


func new_game(world_seed: int) -> void:
	data = Migrations.new_game_data(world_seed)
	changed.emit()


## Replace the state with a loaded save. Returns false (and keeps the current state)
## if the save can't be read.
func load_from(raw: Variant) -> bool:
	var migrated := Migrations.migrate(raw)
	if migrated.is_empty():
		return false
	data = migrated
	changed.emit()
	return true


## A deep copy of the state, for saving.
func snapshot() -> Dictionary:
	return data.duplicate(true)


func day() -> int:
	return int(data.get("day", 1))


func half() -> int:
	return int(data.get("half", 0))


func stamina() -> int:
	return int(data["stamina"]["current"])


## Moves time on by half a day (D35). Each morning the boat may leave or call (D42).
func pass_half() -> void:
	var nxt := Calendar.next(day(), half())
	data["day"] = nxt[0]
	data["half"] = nxt[1]
	if half() == 0:
		_boat_morning()


func _boat_morning() -> void:
	var boat: Dictionary = data["boat"]
	var here: Dictionary = boat["here"]
	if not here.is_empty() and int(here["day"]) < day():
		boat["here"] = {}
	if day() >= int(boat["next_day"]):
		boat["calls"] = int(boat["calls"]) + 1
		var who := Boat.visitors(int(data["world_seed"]), boat["calls"])
		who["day"] = day()
		boat["here"] = who
		boat["next_day"] = day() + Boat.gap(int(data["world_seed"]), boat["calls"])


## Who the boat brought ({trader, collector, day}), or {} when it's away.
func boat_here() -> Dictionary:
	return data["boat"]["here"]


func coin() -> int:
	return int(data.get("coin", 0))


## Sells finds[i] to the trader on the boat. Returns what happened, in words.
func sell_find(i: int) -> String:
	var here := boat_here()
	var finds: Array = data["finds"]
	if here.is_empty() or i < 0 or i >= finds.size():
		return "Nothing to sell."
	var price := Boat.offer(here["trader"], finds[i])
	var find: Dictionary = finds[i]
	finds.remove_at(i)
	data["coin"] = coin() + price
	changed.emit()
	return "Sold the %s for %d coin." % [find["id"], price]


## Sells every crystal to a trader who buys them.
func sell_crystals() -> String:
	var here := boat_here()
	var inv: Dictionary = data["inventory"]
	var n := int(inv.get("Crystal", 0))
	var price := Boat.crystal_offer(here["trader"]) if not here.is_empty() else 0
	if n == 0 or price == 0:
		return "No crystals to sell here."
	inv["Crystal"] = 0
	data["coin"] = coin() + n * price
	changed.emit()
	return "Sold %d crystal%s for %d coin." % [n, "" if n == 1 else "s", n * price]


## Buys a piece of gear from the outfitter.
func buy_gear(item: String) -> String:
	var here := boat_here()
	if here.is_empty() or not Boat.sells_gear(here["trader"]):
		return "Nobody here sells gear."
	var gear: Dictionary = data["gear"]
	var price: int = Boat.GEAR_PRICES[item]
	if int(gear.get(item, 0)) >= Crafting.PACK_CAP:
		return "You can't carry more than %d." % Crafting.PACK_CAP
	if coin() < price:
		return "That's %d coin; you have %d." % [price, coin()]
	data["coin"] = coin() - price
	gear[item] = int(gear.get(item, 0)) + 1
	changed.emit()
	return "Bought a %s." % Crafting.NAMES[item]


## Gives finds[i] to the collector on the boat for their museum's collection (D43).
func donate(i: int) -> String:
	var here := boat_here()
	var finds: Array = data["finds"]
	if here.is_empty() or here["collector"] == "" or i < 0 or i >= finds.size():
		return "Nobody here to donate to."
	var collection: String = Boat.COLLECTORS[here["collector"]]["collection"]
	var find: Dictionary = finds[i]
	if Finds.collection_of(find["id"]) != collection:
		return "That isn't part of %s." % Finds.COLLECTIONS[collection]["name"]
	var museums: Dictionary = data["museums"]
	if not museums.has(collection):
		museums[collection] = {"donated": [], "renown": 0, "complete": false}
	var m: Dictionary = museums[collection]
	if (m["donated"] as Array).has(find["id"]):
		return "They already have a %s." % find["id"]
	finds.remove_at(i)
	m["donated"].append(find["id"])
	m["renown"] = int(m["renown"]) + (2 if find.get("context") == "documented" else 1)
	var out := "Donated the %s to %s." % [find["id"], Finds.COLLECTIONS[collection]["name"]]
	var all_finds: Array = Finds.COLLECTIONS[collection]["finds"]
	if not m["complete"] and all_finds.all(func(f: String) -> bool: return m["donated"].has(f)):
		m["complete"] = true
		data["coin"] = coin() + Boat.COLLECTION_REWARD
		out += " The collection is complete! A grant of %d coin." % Boat.COLLECTION_REWARD
	changed.emit()
	return out


## A full rest at the tent: half a day passes and stamina is full again (D35).
func rest() -> void:
	pass_half()
	var st: Dictionary = data["stamina"]
	st["current"] = st["max"]
	changed.emit()


## Gathers from a plant. Returns "" and adds to the inventory, or returns why not.
func gather(id: String, kind: String) -> String:
	var forage: Dictionary = data["forage"]
	var reason := Forage.why_not(kind, int(forage.get(id, 0)), day(), half())
	if reason == "":
		if stamina() < Forage.GATHER_COST:
			reason = "Too tired. Rest at the tent."
	if reason != "":
		return reason
	var got := Forage.yield_now(kind, day())
	var inventory: Dictionary = data["inventory"]
	inventory[kind] = int(inventory.get(kind, 0)) + got
	forage[id] = Forage.regrown_at(kind, day(), half())
	data["stamina"]["current"] = stamina() - Forage.GATHER_COST
	changed.emit()
	return ""


## Crafts one piece of gear at the workbench. Returns "" or why not.
func craft(item: String) -> String:
	var reason := Crafting.why_not(item, data["inventory"], data["gear"])
	if reason == "":
		Crafting.craft(item, data["inventory"], data["gear"])
		changed.emit()
	return reason


## Packs all gear for an expedition and takes it out of camp. Returns the pack.
func pack_for_expedition() -> Dictionary:
	expedition_pack = (data["gear"] as Dictionary).duplicate()
	data["gear"] = {"anchor": 0, "flare": 0, "ration": 0}
	return expedition_pack


## What the island's time and season do to the tomb (D36).
func expedition_conditions() -> Dictionary:
	return {"night": Calendar.is_night(half()), "rains": Calendar.season(day()) == 1}


## Brings an expedition's results home: finds go to the finds list, materials to the
## inventory, unused gear back to camp, and stamina is whatever was left. An expedition always
## takes half a day (D35).
func apply_expedition(bag: Array, stamina_left: int, pack_left: Dictionary = {}) -> void:
	var gear: Dictionary = data["gear"]
	for item: String in pack_left:
		gear[item] = int(gear.get(item, 0)) + int(pack_left[item])
	pass_half()
	var finds: Array = data["finds"]
	var inventory: Dictionary = data["inventory"]
	for item: Dictionary in bag:
		if item.get("kind") == "material":
			inventory[item["id"]] = int(inventory.get(item["id"], 0)) + 1
		else:
			var find := item.duplicate()
			find.erase("kind")
			finds.append(find)
	var stamina: Dictionary = data["stamina"]
	stamina["current"] = clampi(stamina_left, 0, int(stamina["max"]))
	changed.emit()
