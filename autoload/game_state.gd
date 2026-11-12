extends Node
## The single owner of everything that is saved.
##
## Scenes read `data` and change it only through methods here (or core/ functions whose
## results are written back here), then the `changed` signal tells everyone to refresh.

signal changed

const Migrations := preload("res://core/save_migrations.gd")

var data: Dictionary = {}


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


## Sleeping ends the day: the next day starts with full stamina.
func sleep() -> void:
	data["day"] = int(data.get("day", 1)) + 1
	var stamina: Dictionary = data["stamina"]
	stamina["current"] = stamina["max"]
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
