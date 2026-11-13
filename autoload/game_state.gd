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


## Moves time on by half a day (D35).
func pass_half() -> void:
	var nxt := Calendar.next(day(), half())
	data["day"] = nxt[0]
	data["half"] = nxt[1]


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


## Brings an expedition's results home: finds go to the finds list, materials to the
## inventory, and the day's stamina is whatever was left.
func apply_expedition(bag: Array, stamina_left: int) -> void:
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
