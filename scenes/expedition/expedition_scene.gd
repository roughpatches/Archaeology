extends Node2D
## Gray-box expedition (FEEL_EXPEDITION.md). Coloured squares only; ` shows the debug overlay.
##
## Explore: arrows/WASD move, Q survey, F flare, E use (rope, stairs, dig spot). Tunnels
## branch; each ends in a one-way drop, and each mouth shows a hint (checked by a survey).
## Dig: 1-4 pick tool, click a tile, L lift, Esc or E back out. Esc while exploring pauses:
## give up (Philius hauls you out, half the bag lost) or quit the game.

const Expedition := preload("res://core/expedition/expedition.gd")
const FloorGen := preload("res://core/expedition/floor_gen.gd")
const DigView := preload("res://scenes/expedition/dig_view.gd")
const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")
const Art := preload("res://scenes/art.gd")

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
	"shaft": Color("fff3a8"),
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
## Art for each tile kind (D49); walls with open ground below show their face instead.
const TILE_ART := {
	FloorGen.Tile.WALL: "tomb/wall",
	FloorGen.Tile.FLOOR: "tomb/floor",
	FloorGen.Tile.PILLAR: "tomb/pillar",
	FloorGen.Tile.LEDGE: "tomb/ledge",
	FloorGen.Tile.RUBBLE: "tomb/rubble",
}
const TILE_COLOR := {
	FloorGen.Tile.WALL: "wall",
	FloorGen.Tile.FLOOR: "floor",
	FloorGen.Tile.PILLAR: "pillar",
	FloorGen.Tile.LEDGE: "ledge",
	FloorGen.Tile.WATER: "water",
	FloorGen.Tile.RUBBLE: "rubble",
}
## The camera is close in, so a chamber is bigger than the screen (D34).
const ZOOM := 2.0
## Seconds the player takes to glide one tile.
const STEP_TIME := 0.14

var run: Expedition
var mode := "explore"
var dig_spot := -1

var _camera := Camera2D.new()
## Where the player is drawn, in pixels: it glides to the player's tile after each step.
var _shown := Vector2.ZERO
## Time left on the current step's glide; holding a direction steps again when it runs out.
var _step_left := 0.0
var _hud_layer := CanvasLayer.new()
var _hud := Label.new()
var _log := Label.new()
var _dig_layer := CanvasLayer.new()
var _dig_view: DigView


func _ready() -> void:
	var stamina := int(GameState.data.get("stamina", {}).get("current", 100))
	var pack: Dictionary = GameState.expedition_pack
	if pack.is_empty():
		pack = {"anchor": 0, "flare": 0, "ration": 0}
	run = Expedition.new(randi(), stamina, pack, GameState.expedition_conditions())
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
			GameState.apply_expedition(run.bag, run.stamina, run.pack_left())
			GameState.expedition_pack = {}
			GameState.back_from_tomb = true
			SaveService.save_game()
			get_tree().change_scene_to_file("res://scenes/overworld/overworld.tscn")
		return
	if mode == "dig":
		return  # DigView handles its own keys.
	if mode == "paused" or key.keycode == KEY_ESCAPE:
		if not key.echo:
			_paused_key(key.keycode)
		get_viewport().set_input_as_handled()
		return
	_explore_key(key)


## Walking and the explore keys.
func _explore_key(key: InputEventKey) -> void:
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
		if not key.echo and _step_left <= 0.0:
			_step(dir)
		get_viewport().set_input_as_handled()
		return
	if key.echo:
		return
	if key.keycode == KEY_Q:
		run.survey()
	elif key.keycode == KEY_F:
		run.use_flare()
	elif key.keycode == KEY_E:
		_interact()
	elif key.keycode == KEY_T:
		var why := run.place_anchor()
		if why != "":
			run.log_lines.append(why)
	elif key.keycode == KEY_R:
		var why := run.eat_ration()
		if why != "":
			run.log_lines.append(why)
	else:
		return
	get_viewport().set_input_as_handled()
	_after_action()


## Esc pauses; while paused, Esc carries on, G gives up, Q quits the game.
func _paused_key(keycode: int) -> void:
	if mode != "paused":
		mode = "paused"
		_refresh()
		return
	match keycode:
		KEY_ESCAPE:
			mode = "explore"
		KEY_G:
			run.give_up()
			mode = "result"
		KEY_Q:
			# The save was made as you set out, so the trip never happened.
			get_tree().quit()
	_refresh()


## Turn-based rules (D29), smooth look (D41): each step is one tick, and the player glides to
## the new tile over STEP_TIME. Holding a direction keeps walking.
func _process(delta: float) -> void:
	if mode != "explore":
		return
	_step_left = maxf(0.0, _step_left - delta)
	var target := _tile_centre(run.player)
	if _shown != target:
		_shown = _shown.move_toward(target, TILE / STEP_TIME * delta)
		_camera.position = _shown
		queue_redraw()
	if _step_left <= 0.0:
		var dir := _held_direction()
		if dir != Vector2i.ZERO:
			_step(dir)


func _step(dir: Vector2i) -> void:
	_step_left = STEP_TIME
	run.move(dir)
	_after_action()


func _held_direction() -> Vector2i:
	for pair: Array in [
		[[KEY_LEFT, KEY_A], Vector2i.LEFT],
		[[KEY_RIGHT, KEY_D], Vector2i.RIGHT],
		[[KEY_UP, KEY_W], Vector2i.UP],
		[[KEY_DOWN, KEY_S], Vector2i.DOWN],
	]:
		for k: Key in pair[0]:
			if Input.is_physical_key_pressed(k):
				return pair[1]
	return Vector2i.ZERO


func _tile_centre(p: Vector2i) -> Vector2:
	return Vector2(p * TILE) + Vector2(TILE, TILE) / 2.0


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
	if _shown.distance_to(_tile_centre(run.player)) > TILE * 2:
		_shown = _tile_centre(run.player)
	_camera.position = _shown
	var lines: Array[String] = []
	(
		lines
		. append(
			(
				"Floor %d/%d   Stamina %d   Bag %d/%d   Flares %d  Anchors %d  Rations %d"
				% [
					run.depth,
					Expedition.FLOORS,
					run.stamina,
					run.bag.size(),
					run.bag_slots,
					run.flares,
					run.anchors_left,
					run.rations,
				]
			)
		)
	)
	if mode == "result":
		lines.append("")
		lines.append(_result_text())
	elif mode == "paused":
		lines.append("")
		lines.append("PAUSED   Esc: carry on")
		lines.append("G: give up. Philius hauls you out; half the bag is lost.")
		lines.append(
			"Q: quit the game. The trip never happened: you're back as you were before setting out."
		)
	else:
		var hint := (
			"WASD move  Q survey (%d)  F flare  T anchor (%d)  R ration  E use"
			% [Expedition.SURVEY_COST, Expedition.ANCHOR_COST]
		)
		if run.can_climb_out():
			hint += "   [way out: E climbs out]"
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
	var size: Vector2i = run.floor_data["size"]
	for p: Vector2i in run.lit:
		if p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y:
			_draw_tile(p)
	if not run.rumble.is_empty():
		for p: Vector2i in run.rumble["tiles"]:
			if run.lit.has(p):
				var o := Vector2(p * TILE)
				draw_rect(Rect2(o, Vector2(TILE, TILE)), COLORS["dust"])
				for k in 3:
					draw_circle(
						o + Vector2(3 + 5 * k, 3 + 4 * ((k + run.ticks) % 3)), 1, Color.WHEAT
					)
	_draw_markers()
	for s in run.spots:
		if not s["noticed"]:
			continue
		var state := "done"
		var col: Color = COLORS["spot_done"]
		if not s["dig"].lifted:
			state = "mapped" if s["dig"].surveyed else "sign"
			col = COLORS["spot_mapped"] if s["dig"].surveyed else COLORS["spot"]
		_mark(s["pos"], col, "dig", "tomb/dig_spot_" + state)
	for n in run.nodes:
		_mark(n, COLORS["node"], "", "tomb/crystal")
	_draw_actors()
	_draw_lamp_fade()
	for h in run.tunnel_hints():
		if run.lit.has(h["pos"]):
			_hint_label(h)


## One lit floor tile: art if there is some (D49), else the gray-box colour.
func _draw_tile(p: Vector2i) -> void:
	var t := FloorGen.tile_at(run.floor_data, p)
	var rect := Rect2(Vector2(p * TILE), Vector2(TILE, TILE))
	var art: String = TILE_ART.get(t, "")
	if (
		t == FloorGen.Tile.WALL
		and FloorGen.open(FloorGen.tile_at(run.floor_data, p + Vector2i.DOWN))
	):
		art = "tomb/wall_face"
	elif t == FloorGen.Tile.WATER:
		art = "tomb/stream_%d" % ((_hash(p) + run.ticks) % 4)
	var tex := Art.tex(art)
	if tex != null:
		draw_texture(tex, rect.position)
		if t == FloorGen.Tile.LEDGE:
			_chevron(p)
		return
	var c: Color = COLORS[TILE_COLOR.get(t, "wall")]
	draw_rect(rect, c)
	if t == FloorGen.Tile.WALL and _hash(p) % 4 == 0:
		var o := Vector2(p * TILE)
		draw_line(o + Vector2(3, 0), o + Vector2(5, TILE), COLORS["root"], 1.5)
	elif t == FloorGen.Tile.RUBBLE:
		draw_circle(rect.get_center() + Vector2(-3, 2), 3, c.lightened(0.2))
		draw_circle(rect.get_center() + Vector2(3, -2), 2.5, c.lightened(0.15))
	elif t == FloorGen.Tile.LEDGE:
		_chevron(p)


## Ways out, the way down and springs.
func _draw_markers() -> void:
	if run.depth <= run.rope_floors:
		_mark(run.floor_data["entry"], COLORS["rope"], "rope", "tomb/rope")
	for an in run.anchors:
		_mark(an, COLORS["rope"], "anchor", "tomb/anchor")
	for c: Dictionary in run.floor_data["chambers"]:
		if c["shaft"] != FloorGen.NO_SHAFT:
			_mark(c["shaft"], COLORS["shaft"], "daylight", "tomb/shaft")
	for e: Vector2i in run.floor_data["exits"]:
		if run.depth >= Expedition.FLOORS:
			_mark(e, COLORS["rope"], "rope", "tomb/rope")
		else:
			_mark(e, COLORS["stairs"], "down", "tomb/stairs")
	for sp in run.springs:
		_mark(sp, COLORS["spring"], "", "tomb/spring")


## Creatures and the player, sorted by the y of their feet (contract section 3).
func _draw_actors() -> void:
	var actors: Array = []
	for cr in run.creatures:
		if run.lit.has(cr["pos"]):
			actors.append([_tile_centre(cr["pos"]).y, cr])
	actors.append([_shown.y, {}])
	actors.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in actors:
		var cr: Dictionary = item[1]
		if cr.is_empty():
			if not Art.draw_feet(self, "characters/player", _shown + Vector2(0, 7)):
				draw_rect(
					Rect2(_shown - Vector2(TILE - 6, TILE - 6) / 2.0, Vector2(TILE - 6, TILE - 6)),
					COLORS["player"]
				)
			continue
		var state := "normal"
		var col: Color = COLORS["creature"]
		if cr["flee"] > 0:
			state = "flee"
			col = COLORS["creature_flee"]
		elif cr["stun"] > 0:
			state = "stunned"
			col = COLORS["creature_stun"]
		var centre := _tile_centre(cr["pos"])
		if not Art.draw_feet(self, "characters/creature_" + state, centre + Vector2(0, 7)):
			draw_circle(centre, TILE * 0.4, col)


## The lamp fades toward the edge of its reach, drawn over the art (contract section 3).
func _draw_lamp_fade() -> void:
	for p: Vector2i in run.lit:
		var k := maxi(0, _dist(p) - 2)
		if k > 0:
			draw_rect(
				Rect2(Vector2(p * TILE), Vector2(TILE, TILE)), Color(0, 0, 0, minf(0.12 * k, 0.8))
			)


## A marked tile: its art if there is some, else a coloured frame; and its label (labels stay
## drawn by code, contract section 9).
func _mark(p: Vector2i, col: Color, label: String, art: String = "") -> void:
	if not run.lit.has(p):
		return
	var tex := Art.tex(art) if art != "" else null
	if tex != null:
		draw_texture(tex, Vector2(p * TILE))
	else:
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
