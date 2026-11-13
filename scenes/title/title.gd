extends Node2D
## Title screen (gray-box): continue the saved game, start a new one, or quit.
## Up/down (or W/S) choose, Enter picks.

const OVERWORLD := "res://scenes/overworld/overworld.tscn"

var _choice := 0
var _confirm_new := false
var _note := ""
var _label := Label.new()


func _ready() -> void:
	_label.position = Vector2(40, 60)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)
	_show()


## The menu's entries, in order. Continue only shows when there is a save.
func options() -> Array[String]:
	var out: Array[String] = []
	if SaveService.has_save():
		out.append("continue")
	out.append_array(["new", "quit"])
	return out


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var n := options().size()
	match key.keycode:
		KEY_UP, KEY_W:
			_choice = (_choice + n - 1) % n
			_confirm_new = false
		KEY_DOWN, KEY_S:
			_choice = (_choice + 1) % n
			_confirm_new = false
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			_pick(options()[_choice])
		_:
			return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
		_show()


func _pick(option: String) -> void:
	match option:
		"continue":
			if SaveService.load_game() == OK:
				get_tree().change_scene_to_file(OVERWORLD)
			else:
				_note = "The save couldn't be read (it may be from a newer version)."
		"new":
			# Starting over replaces the save, so ask once when there is one.
			if SaveService.has_save() and not _confirm_new:
				_confirm_new = true
				return
			GameState.new_game(randi())
			SaveService.save_game()
			get_tree().change_scene_to_file(OVERWORLD)
		"quit":
			get_tree().quit()


func _show() -> void:
	var names := {"continue": "Continue", "new": "New game", "quit": "Quit"}
	var lines: Array[String] = [
		"ARCHAEOLOGY  (working title)", "An island. A tomb. A professor.", ""
	]
	var opts := options()
	for i in opts.size():
		lines.append(("> " if i == _choice else "  ") + names[opts[i]])
	if _confirm_new:
		lines.append("")
		lines.append("This replaces your saved game. Enter again to start over.")
	if _note != "":
		lines.append("")
		lines.append(_note)
	_label.text = "\n".join(lines)
