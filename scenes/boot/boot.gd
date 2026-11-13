extends Node2D
## Placeholder camp for the gray-box: start an expedition, sleep, save and load.
## Replaced by the real camp once the expedition passes its playtest.

const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")

var _label := Label.new()
var _status := ""


func _ready() -> void:
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)
	add_child(DebugOverlay.new())
	GameState.changed.connect(_refresh)
	if not GameState.data.is_empty():
		_status = "Back at camp."
	elif SaveService.has_save() and SaveService.load_game() == OK:
		_status = "Loaded your save."
	else:
		GameState.new_game(randi())
		_status = "New game."
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_Z:
			GameState.sleep()
			_status = "You slept. A new day."
		KEY_S:
			_status = "Saved." if SaveService.save_game() == OK else "Save failed."
		KEY_L:
			_status = "Loaded." if SaveService.load_game() == OK else "Nothing to load."
		KEY_N:
			GameState.new_game(randi())
			_status = "New game."
		KEY_X:
			get_tree().change_scene_to_file("res://scenes/expedition/expedition.tscn")
			return
		_:
			return
	_refresh()


func _refresh() -> void:
	var d: Dictionary = GameState.data
	var stamina: Dictionary = d.get("stamina", {})
	_label.text = (
		"ARCHAEOLOGY  (camp placeholder)\n\n"
		+ (
			"Day %d   Stamina %d / %d   World seed %d\n\n"
			% [
				d.get("day", 0),
				stamina.get("current", 0),
				stamina.get("max", 0),
				d.get("world_seed", 0)
			]
		)
		+ (
			"Finds at camp: %d   Crystals: %d\n\n"
			% [d.get("finds", []).size(), d.get("inventory", {}).get("Crystal", 0)]
		)
		+ "X expedition   Z sleep   S save   L load   N new game   ` debug\n\n"
		+ _status
	)
