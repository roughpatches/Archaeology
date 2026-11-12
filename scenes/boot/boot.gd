extends Node2D
## Placeholder start scene for the setup phase: proves the project runs, saves and loads.
## Replaced by the expedition gray-box.

const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")

var _label := Label.new()
var _status := ""


func _ready() -> void:
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)
	add_child(DebugOverlay.new())
	GameState.changed.connect(_refresh)
	if SaveService.has_save() and SaveService.load_game() == OK:
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
		_:
			return
	_refresh()


func _refresh() -> void:
	var d: Dictionary = GameState.data
	var stamina: Dictionary = d.get("stamina", {})
	_label.text = (
		"ARCHAEOLOGY  (Godot setup)\n\n"
		+ (
			"Day %d   Stamina %d / %d   World seed %d\n\n"
			% [
				d.get("day", 0),
				stamina.get("current", 0),
				stamina.get("max", 0),
				d.get("world_seed", 0)
			]
		)
		+ "Z sleep   S save   L load   N new game   ` debug\n\n"
		+ _status
	)
