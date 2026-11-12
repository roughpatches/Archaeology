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
