extends Node2D
## Gray-box expedition (FEEL_EXPEDITION.md). Coloured squares only; ` shows the debug overlay.
##
## Explore: arrows/WASD move, Q survey, F flare, E use (rope, stairs, dig spot). Tunnels
## branch; each ends in a one-way drop, and each mouth shows a hint (checked by a survey).
## Dig: 1-4 pick tool, click a tile, L lift, Esc or E back out.

const Expedition := preload("res://core/expedition/expedition.gd")
const FloorGen := preload("res://core/expedition/floor_gen.gd")
const DigView := preload("res://scenes/expedition/dig_view.gd")
const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")

const TILE := 16
## Jungle tomb palette (D33). Gray-box: flat colours, no art.
const COLORS := {
	"wall": Color("1f2a1e"),
	"floor": Color("6f6a52"),
	"pillar": Color("3b4a33"),
	"ledge": Color("a59a70"),
	"water": Color("2f6f8f"),
	"rubble": Color("54493c"),
	"root": Color("3f6b2e"),
	"dust": Color(0.85, 0.7, 0.45, 0.45),
	"unseen": Color("050504"),
	"player": Color("4aa3ff"),
	"rope": Color("5fd35f"),
	"stairs": Color("b07cff"),
	"spot": Color("ff9a3c"),
	"spot_mapped": Color("ffd84a"),
	"spot_done": Color("5a5a5a"),
	"node": Color("5ff0e6"),
	"creature": Color("e8433a"),
	"creature_flee": Color("ff9ccf"),
	"creature_stun": Color("7a2a26"),
	"spring": Color("7fd4ff"),
	"hint": Color("d8cfc0"),
	"hint_checked": Color("ffd84a"),
}
## The camera is close in, so a chamber is bigger than the screen (D34).
const ZOOM := 2.0

var run: Expedition
var mode := "explore"
var dig_spot := -1

var _camera := Camera2D.new()
var _hud_layer := CanvasLayer.new()
var _hud := Label.new()
var _log := Label.new()
var _dig_layer := CanvasLayer.new()
var _dig_view: DigView


func _ready() -> void:
	var stamina := int(GameState.data.get("stamina", {}).get("current", 100))
	run = Expedition.new(randi(), stamina)
	_camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(_camera)
	_hud.position = Vector2(6, 4)
	_hud.add_theme_font_size_override("font_size", 8)
	_log.position = Vector2(6, 226)
	_log.add_theme_font_size_override("font_size", 7)
	_hud_layer.add_child(_hud)
	_hud_layer.add_child(_log)
	add_child(_hud_layer)
	_dig_layer.layer = 10
	_dig_view = DigView.new()
	_dig_view.scene = self
	_dig_layer.add_child(_dig_view)
	_dig_layer.visible = false
	add_child(_dig_layer)
	add_child(DebugOverlay.new())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if mode == "result":
		if not key.echo and key.keycode in [KEY_ENTER, KEY_E, KEY_SPACE]:
			GameState.apply_expedition(run.bag, run.stamina)
			get_tree().change_scene_to_file("res://scenes/boot/boot.tscn")
		return
	if mode == "dig":
		return  # DigView handles its own keys.
	var dir := Vector2i.ZERO
	match key.keycode:
		KEY_LEFT, KEY_A:
			dir = Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			dir = Vector2i.RIGHT
		KEY_UP, KEY_W:
			dir = Vector2i.UP
		KEY_DOWN, KEY_S:
			dir = Vector2i.DOWN
	if dir != Vector2i.ZERO:
		run.move(dir)
	elif key.echo:
		return
	elif key.keycode == KEY_Q:
		run.survey()
	elif key.keycode == KEY_F:
		run.use_flare()
	elif key.keycode == KEY_E:
		_interact()
	else:
		return
	get_viewport().set_input_as_handled()
	_after_action()


func _interact() -> void:
	if run.on_exit() and run.depth < Expedition.FLOORS:
		if not run.descend():
			run.log_lines.append(
				(
					"Too tired to go down."
					if run.depth < Expedition.FLOORS
					else "This is the deepest floor."
				)
			)
	elif run.can_climb_out():
		run.climb_out()
	else:
		var s := run.spot_at(run.player)
		if s >= 0 and not run.spots[s]["dig"].lifted:
			open_dig(s)


func open_dig(s: int) -> void:
	mode = "dig"
	dig_spot = s
	run.spots[s]["noticed"] = true
	_dig_layer.visible = true
	_dig_view.open(run, s)


func close_dig() -> void:
	mode = "explore"
	dig_spot = -1
	_dig_layer.visible = false
	_after_action()


## Called after anything that changes the run.
func _after_action() -> void:
	if run.is_over() and mode != "result":
		mode = "result"
		_dig_layer.visible = false
	_refresh()


func _refresh() -> void:
	_camera.position = Vector2(run.player * TILE) + Vector2(TILE, TILE) / 2.0
	var lines: Array[String] = []
	lines.append(
		(
			"Floor %d/%d   Stamina %d   Bag %d/%d   Flares %d"
			% [
				run.depth,
				Expedition.FLOORS,
				run.stamina,
				run.bag.size(),
				Expedition.BAG_SLOTS,
				run.flares
			]
		)
	)
	if mode == "result":
		lines.append("")
		lines.append(_result_text())
	else:
		var hint := "Move WASD  Q survey (%d)  F flare  E use" % Expedition.SURVEY_COST
		if run.can_climb_out():
			hint += "   [rope: E climbs out]"
		elif run.on_ledge():
			hint += "   [drop: step on and there's no way back]"
		elif run.on_exit():
			hint += "   [stairs: E goes down, %d stamina]" % Expedition.DESCEND_COST
		elif run.spot_at(run.player) >= 0:
			hint += "   [dig spot: E digs]"
		lines.append(hint)
		if run.hunted():
			lines.append("Something is closing in...")
		if not run.rumble.is_empty():
			lines.append("The tomb rumbles...")
	_hud.text = "\n".join(lines)
	_log.text = "\n".join(run.log_lines.slice(maxi(0, run.log_lines.size() - 3)))
	queue_redraw()
	if mode == "dig":
		_dig_view.queue_redraw()


func _result_text() -> String:
	var out := "CLIMBED OUT" if run.state == "climbed_out" else "COLLAPSED"
	out += " after %d ticks, reached floor %d.\n" % [run.ticks, run.depth]
	if run.bag.is_empty():
		out += "Nothing brought home.\n"
	for item in run.bag:
		if item["kind"] == "find":
			out += (
				"  %s  (%s, %s, %s)\n"
				% [item["id"], item["rarity"], item["condition"], item["context"]]
			)
		else:
			out += "  %s\n" % item["id"]
	return out + "\nEnter: back to camp"


func _draw() -> void:
	var view := get_viewport_rect().size / ZOOM
	var origin := _camera.position - view / 2.0
	draw_rect(Rect2(origin, view), COLORS["unseen"])
	var tiles: PackedByteArray = run.floor_data["tiles"]
	var size: Vector2i = run.floor_data["size"]
	for p: Vector2i in run.lit:
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
			continue
		var t: int = tiles[p.y * size.x + p.x]
		var c: Color = COLORS["wall"]
		match t:
			FloorGen.Tile.FLOOR:
				c = COLORS["floor"]
			FloorGen.Tile.LEDGE:
				c = COLORS["ledge"]
			FloorGen.Tile.PILLAR:
				c = COLORS["pillar"]
			FloorGen.Tile.WATER:
				c = COLORS["water"]
			FloorGen.Tile.RUBBLE:
				c = COLORS["rubble"]
		# The lamp fades toward the edge of its reach.
		c = c.darkened(0.12 * maxi(0, _dist(p) - 2))
		var rect := Rect2(Vector2(p * TILE), Vector2(TILE, TILE))
		draw_rect(rect, c)
		if t == FloorGen.Tile.WALL and _hash(p) % 4 == 0:
			var o := Vector2(p * TILE)
			draw_line(o + Vector2(3, 0), o + Vector2(5, TILE), COLORS["root"], 1.5)
		elif t == FloorGen.Tile.RUBBLE:
			draw_circle(rect.get_center() + Vector2(-3, 2), 3, c.lightened(0.2))
			draw_circle(rect.get_center() + Vector2(3, -2), 2.5, c.lightened(0.15))
		elif t == FloorGen.Tile.WATER and (_hash(p) + run.ticks) % 3 == 0:
			var o := Vector2(p * TILE)
			draw_line(o + Vector2(4, 6), o + Vector2(10, 6), COLORS["water"].lightened(0.3), 1.0)
	if not run.rumble.is_empty():
		for p: Vector2i in run.rumble["tiles"]:
			if run.lit.has(p):
				var o := Vector2(p * TILE)
				draw_rect(Rect2(o, Vector2(TILE, TILE)), COLORS["dust"])
				for k in 3:
					draw_circle(
						o + Vector2(3 + 5 * k, 3 + 4 * ((k + run.ticks) % 3)), 1, Color.WHEAT
					)
	_mark(run.floor_data["entry"], COLORS["rope"], "rope")
	for e: Vector2i in run.floor_data["exits"]:
		if run.depth >= Expedition.FLOORS:
			_mark(e, COLORS["rope"], "rope")
		else:
			_mark(e, COLORS["stairs"], "down")
	for t: Dictionary in run.floor_data["tunnels"]:
		if run.lit.has(t["ledge"]):
			_chevron(t["ledge"])
	for sp in run.springs:
		_mark(sp, COLORS["spring"], "")
	for h in run.tunnel_hints():
		if run.lit.has(h["pos"]):
			_hint_label(h)
	for s in run.spots:
		if not s["noticed"]:
			continue
		var col: Color = COLORS["spot_done"]
		if not s["dig"].lifted:
			col = COLORS["spot_mapped"] if s["dig"].surveyed else COLORS["spot"]
		_mark(s["pos"], col, "dig")
	for n in run.nodes:
		_mark(n, COLORS["node"], "")
	for cr in run.creatures:
		if run.lit.has(cr["pos"]):
			var col: Color = COLORS["creature"]
			if cr["flee"] > 0:
				col = COLORS["creature_flee"]
			elif cr["stun"] > 0:
				col = COLORS["creature_stun"]
			draw_circle(Vector2(cr["pos"] * TILE) + Vector2(TILE, TILE) / 2.0, TILE * 0.4, col)
	draw_rect(
		Rect2(Vector2(run.player * TILE) + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)),
		COLORS["player"]
	)


func _mark(p: Vector2i, col: Color, label: String) -> void:
	if not run.lit.has(p):
		return
	var rect := Rect2(Vector2(p * TILE) + Vector2(1, 1), Vector2(TILE - 2, TILE - 2))
	draw_rect(rect, col, false, 2.0)
	if label != "":
		draw_string(
			ThemeDB.fallback_font,
			Vector2(p * TILE) + Vector2(1, -2),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			6,
			col
		)


## The hint for a tunnel, written on the tunnel itself just past its mouth.
func _hint_label(h: Dictionary) -> void:
	var col: Color = COLORS["hint_checked"] if h["checked"] else COLORS["hint"]
	var text: String = h["text"] if h["checked"] else h["text"] + "?"
	var font := ThemeDB.fallback_font
	var at := Vector2((h["pos"] + Vector2i.RIGHT) * TILE) + Vector2(1, 0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	draw_rect(Rect2(at + Vector2(-1, 4), Vector2(width + 2, 9)), Color(0, 0, 0, 0.75))
	draw_string(font, at + Vector2(0, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)


## A ">" on a drop, pointing the only way it goes.
func _chevron(p: Vector2i) -> void:
	var o := Vector2(p * TILE)
	var pts := PackedVector2Array([o + Vector2(5, 4), o + Vector2(11, 8), o + Vector2(5, 12)])
	draw_polyline(pts, COLORS["wall"], 2.0)


func _hash(p: Vector2i) -> int:
	return absi(p.x * 73856093 ^ p.y * 19349663)


func _dist(p: Vector2i) -> int:
	return absi(p.x - run.player.x) + absi(p.y - run.player.y)
