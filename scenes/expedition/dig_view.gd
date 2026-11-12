extends Node2D
## The dig spot screen, drawn over the expedition. Every tool use is a tick, so creatures
## keep moving while you dig.

const Expedition := preload("res://core/expedition/expedition.gd")
const DigSpot := preload("res://core/expedition/dig_spot.gd")

const CELL := 34
const ORIGIN := Vector2(138, 58)
const SOIL := [Color("3b2a1e"), Color("5a3f2a"), Color("7a583a"), Color("9c7a52")]
const KEYS := {KEY_1: "pick", KEY_2: "trowel", KEY_3: "brush", KEY_4: "probe"}

var scene: Node
var run: Expedition
var spot := -1
var tool := "trowel"

var _flash := ""
var _flash_time := 0.0
var _shake := 0.0


func open(p_run: Expedition, p_spot: int) -> void:
	run = p_run
	spot = p_spot
	tool = "trowel"
	_flash = ""
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_time > 0.0 or _shake > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		_shake = maxf(0.0, _shake - delta)
		position = Vector2(randf_range(-2, 2), randf_range(-2, 2)) if _shake > 0.0 else Vector2.ZERO
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().visible or run == null:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if KEYS.has(key.keycode):
			tool = KEYS[key.keycode]
		elif key.keycode == KEY_L:
			_lift()
		elif key.keycode in [KEY_ESCAPE, KEY_E]:
			scene.call("close_dig")
		else:
			return
		get_viewport().set_input_as_handled()
		_changed()
		return
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var cell := ((get_local_mouse_position() - ORIGIN) / CELL).floor()
		if cell.x >= 0 and cell.y >= 0 and cell.x < DigSpot.COLS and cell.y < DigSpot.ROWS:
			_use(int(cell.y) * DigSpot.COLS + int(cell.x))
			get_viewport().set_input_as_handled()


func _use(i: int) -> void:
	var events := run.dig_use(spot, i, tool)
	if events.is_empty():
		var dig: DigSpot = run.spots[spot]["dig"]
		var reason := dig.why_not(i, tool, run.stamina)
		_say_flash(reason if reason != "" else "Can't do that now", 1.6)
	for e in events:
		match e["kind"]:
			"chipped":
				_shake = 0.25
				_say_flash("Chip!", 0.8)
			"exposed":
				_say_flash("Found something!", 0.8)
			"floor":
				pass
	if _dig().is_exposed() and not _dig().lifted:
		_say_flash("Free! Press L to lift", 1.5)
	_changed()


func _lift() -> void:
	if run.bag_full():
		_say_flash("Bag full", 1.0)
		return
	var item := run.dig_lift(spot)
	if item.is_empty():
		_say_flash("Not free yet" if not _dig().is_exposed() else "Too tired", 1.0)
		return
	_say_flash("%s!  %s, %s" % [item["id"], item["condition"].to_upper(), item["context"]], 2.5)
	_changed()


func _changed() -> void:
	scene.call("_after_action")
	queue_redraw()


func _say_flash(text: String, seconds: float) -> void:
	_flash = text
	_flash_time = seconds


func _dig() -> DigSpot:
	return run.spots[spot]["dig"]


func _draw() -> void:
	if run == null or spot < 0:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2(110, 26), Vector2(260, 222)), Color(0, 0, 0, 0.85))
	var dig := _dig()
	var title := "Dig spot (%s)%s" % [dig.rarity, "  - surveyed" if dig.surveyed else ""]
	draw_string(font, Vector2(118, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	var locked: Array = dig.locked_sides() if dig.is_exposed() and not dig.lifted else []
	for i in dig.tiles.size():
		var t: Dictionary = dig.tiles[i]
		var p := ORIGIN + Vector2(i % DigSpot.COLS, i / DigSpot.COLS) * CELL
		var rect := Rect2(p, Vector2(CELL - 2, CELL - 2))
		var removed: int = t["start_depth"] - t["depth"]
		var col: Color = SOIL[mini(removed, SOIL.size() - 1)]
		if t["depth"] == 0:
			col = Color("c9b48a")
			if t["find"]:
				col = Color("2a2a2a") if dig.lifted else Color("f2c94c")
		draw_rect(rect, col)
		if t["chipped"]:
			draw_line(p + Vector2(4, 4), p + Vector2(CELL - 6, CELL - 6), Color("e8433a"), 2.0)
		if dig.shows_stain(i):
			draw_circle(p + Vector2(CELL, CELL) / 2.0 - Vector2(1, 1), 5, Color("2e5e2e"))
		if dig.surveyed and t["find"] and t["depth"] > 0:
			draw_rect(rect.grow(-2), Color("4aa3ff"), false, 1.0)
		if t["probed"] and t["depth"] > 0:
			var mark := str(t["depth"]) + ("!" if t["find"] else "")
			draw_string(
				font, p + Vector2(4, 12), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE
			)
		elif dig.surveyed and t["find"] and t["depth"] > 0:
			draw_string(
				font,
				p + Vector2(4, 12),
				str(t["depth"]),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				9,
				Color("9fd0ff")
			)
		if locked.has(i):
			draw_rect(rect, Color("ff9a3c"), false, 1.5)
	var y := ORIGIN.y + DigSpot.ROWS * CELL + 10
	var tools := ""
	for k: int in KEYS:
		var tool_name: String = KEYS[k]
		var marker := ">" if tool_name == tool else " "
		tools += (
			"%s%s %s(%d)  " % [marker, OS.get_keycode_string(k), tool_name, DigSpot.COST[tool_name]]
		)
	draw_string(font, Vector2(118, y), tools, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	var status := "Stamina %d   L lift (%d" % [run.stamina, DigSpot.LIFT_COST]
	if dig.is_exposed() and not dig.lifted:
		status += ", damage %d" % dig.lift_damage()
	status += ")   Esc leave"
	draw_string(font, Vector2(118, y + 11), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	if run.hunted():
		draw_string(
			font,
			Vector2(260, 40),
			"Something is near!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color("e8433a")
		)
	if _flash_time > 0.0:
		var a := clampf(_flash_time, 0.0, 1.0)
		draw_string(
			font, Vector2(118, 54), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.4, a)
		)
