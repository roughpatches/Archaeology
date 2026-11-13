extends Node2D
## Gray-box overworld (FEEL_OVERWORLD.md): the island around camp. Calm and real-time; no clock
## runs (D35). Walking is free, gathering costs stamina, and time only moves when you rest at
## the tent or go into the tomb.
##
## WASD/arrows walk, E use (tent, workbench, Professor Philius, plants, the tomb). At the
## workbench, 1-3 craft. F5 saves (resting saves too). ` shows the debug overlay.

const IslandMap := preload("res://core/overworld/island_map.gd")
const Calendar := preload("res://core/calendar.gd")
const Forage := preload("res://core/overworld/forage.gd")
const Crafting := preload("res://core/overworld/crafting.gd")
const Philius := preload("res://core/overworld/philius.gd")
const Boat := preload("res://core/boat.gd")
const Finds := preload("res://core/finds.gd")
const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")

const TILE := 16
const ZOOM := 2.0
const SPEED := 72.0
## Half the player's collision box, in pixels.
const HALF_BOX := 5.0
## How far (in tiles, from the player's centre) something can be used from.
const REACH := 1.4
## At night only the lamp lights the way: full light within this many tiles, then it fades.
const NIGHT_LIGHT := 3.0
const NIGHT_FADE := 4.0

## Grass and jungle colours by season (D36): dry, rains, bloom, mists.
const SEASON_GRASS: Array[Color] = [
	Color("a39a55"), Color("4f8a3c"), Color("6aa84f"), Color("6b8270")
]
const SEASON_JUNGLE: Array[Color] = [
	Color("4d5a2c"), Color("1f4a22"), Color("2a5a26"), Color("344a3c")
]
const COLORS := {
	"sand": Color("d9c38c"),
	"sea": Color("2c5d8a"),
	"stone": Color("7a756a"),
	"player": Color("4aa3ff"),
	"tent": Color("c8763a"),
	"bench": Color("8a5a32"),
	"philius": Color("9a6fd1"),
	"tomb": Color("2b2420"),
	"tomb_frame": Color("8f8a70"),
	"fiber": Color("8fd16a"),
	"wood": Color("a0703c"),
	"resin": Color("f0b43c"),
	"fruit": Color("e8504a"),
	"glowcap": Color("7ff0ff"),
	"night": Color("060a1a"),
	"jetty": Color("8a6a44"),
	"boat": Color("6b4a2a"),
	"sail": Color("efe6d0"),
	"trader": Color("e0a040"),
	"collector": Color("40c0a0"),
}
## Map characters with a fixed colour (grass and jungle change with the season).
const GROUND := {
	"~": "sea",
	"B": "sea",
	",": "sand",
	"@": "sand",
	"V": "sand",
	"C": "sand",
	"o": "stone",
	"=": "jetty",
	"E": "tomb_frame",
}
## Keys the outfitter sells gear on (1-9 sell finds, 0 sells crystals).
const GEAR_KEYS := {KEY_Z: "anchor", KEY_X: "flare", KEY_C: "ration"}
## At most this many finds are listed for selling or donating.
const LIST_MAX := 9

const PROMPTS := {
	"tent": "E: rest half a day (full stamina)",
	"philius": "E: talk to Professor Philius",
	"tomb": "E: set out into the tomb (half a day)",
}

var player_pos := Vector2.ZERO
var _things: Array[Dictionary] = []
var _message := ""
var _confirm_tomb := false
var _philius_talks := 0
var _camera := Camera2D.new()
var _hud_layer := CanvasLayer.new()
var _hud := Label.new()
var _prompt := Label.new()


func _ready() -> void:
	if GameState.data.is_empty():
		GameState.new_game(randi())
	_things = IslandMap.things()
	player_pos = _centre_of(IslandMap.start())
	_camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(_camera)
	_hud.position = Vector2(6, 4)
	_hud.add_theme_font_size_override("font_size", 8)
	_prompt.position = Vector2(6, 228)
	_prompt.add_theme_font_size_override("font_size", 8)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.6)
	panel.set_content_margin_all(3)
	_prompt.add_theme_stylebox_override("normal", panel)
	_hud_layer.add_child(_hud)
	_hud_layer.add_child(_prompt)
	add_child(_hud_layer)
	add_child(DebugOverlay.new())
	GameState.changed.connect(_refresh)
	if not GameState.expedition_pack.is_empty() or GameState.back_from_tomb:
		GameState.back_from_tomb = false
		player_pos = _centre_of(_tomb_pos() + Vector2i.DOWN)
	_refresh()


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir += _wasd()
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var step := dir * SPEED * delta
	if _free(player_pos + Vector2(step.x, 0)):
		player_pos.x += step.x
	if _free(player_pos + Vector2(0, step.y)):
		player_pos.y += step.y
	if _confirm_tomb and _nearest() != _tomb_index():
		_confirm_tomb = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_E:
			_use()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_number(key.keycode - KEY_1)
		KEY_0:
			if _near_kind() == "trader":
				_message = GameState.sell_crystals()
		KEY_Z, KEY_X, KEY_C:
			if _near_kind() == "trader":
				_message = GameState.buy_gear(GEAR_KEYS[key.keycode])
		KEY_F5:
			_message = "Saved." if SaveService.save_game() == OK else "Save failed."
		_:
			return
	# Setting out for the tomb changes scene; this node is then leaving the tree.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
		_refresh()


## A number key: craft at the bench, sell to the trader, or donate to the collector.
func _number(n: int) -> void:
	match _near_kind():
		"bench":
			if n < Crafting.ORDER.size():
				var item: String = Crafting.ORDER[n]
				var why := GameState.craft(item)
				_message = "Made a %s." % Crafting.NAMES[item] if why == "" else why
		"trader":
			var finds := _listed_finds("")
			if n < finds.size():
				_message = GameState.sell_find(finds[n])
		"collector":
			var finds := _listed_finds(_collection_here())
			if n < finds.size():
				_message = GameState.donate(finds[n])


## Indices into the saved finds, at most LIST_MAX, optionally only one collection's.
func _listed_finds(collection: String) -> Array[int]:
	var out: Array[int] = []
	var finds: Array = GameState.data["finds"]
	for i in finds.size():
		if collection == "" or Finds.collection_of(finds[i]["id"]) == collection:
			out.append(i)
		if out.size() >= LIST_MAX:
			break
	return out


func _collection_here() -> String:
	var here := GameState.boat_here()
	if here.is_empty() or here["collector"] == "":
		return ""
	return Boat.COLLECTORS[here["collector"]]["collection"]


## Whether a thing is on the island right now (visitors only come with the boat).
func _present(kind: String) -> bool:
	var here := GameState.boat_here()
	match kind:
		"trader", "boat":
			return not here.is_empty()
		"collector":
			return not here.is_empty() and here["collector"] != ""
	return true


func _use() -> void:
	var i := _nearest()
	if i < 0:
		return
	var thing: Dictionary = _things[i]
	match thing["kind"]:
		"tent":
			GameState.rest()
			SaveService.save_game()
			_philius_talks = 0
			_message = (
				"You rest until %s. Stamina restored."
				% ("nightfall" if GameState.half() == 1 else "morning")
			)
		"bench":
			_message = "The workbench. Press 1, 2 or 3 to make gear."
		"philius":
			var season: String = Calendar.SEASONS[Calendar.season(GameState.day())]
			_message = (
				'Professor Philius: "%s"'
				% Philius.line(season, Calendar.is_night(GameState.half()), _philius_talks)
			)
			_philius_talks += 1
		"tomb":
			_use_tomb()
		"trader", "collector", "boat":
			_message = _visitor_greeting(thing["kind"])
		_:
			var why := GameState.gather(thing["id"], thing["kind"])
			_message = ("Gathered %s." % Forage.display_name(thing["kind"]) if why == "" else why)


func _use_tomb() -> void:
	if GameState.stamina() <= 0:
		_message = "You're spent. Rest at the tent first."
		return
	if not _confirm_tomb:
		_confirm_tomb = true
		var g: Dictionary = GameState.data["gear"]
		_message = (
			(
				"Into the tomb? It takes half a day. You'd take %d stamina, %d anchor(s), "
				+ "%d flare(s), %d ration(s). E again to go."
			)
			% [GameState.stamina(), g["anchor"], g["flare"], g["ration"]]
		)
		return
	GameState.pack_for_expedition()
	get_tree().change_scene_to_file("res://scenes/expedition/expedition.tscn")


# ---- what's where ---------------------------------------------------------------------


func _player_tile() -> Vector2i:
	return Vector2i((player_pos / TILE).floor())


func _centre_of(t: Vector2i) -> Vector2:
	return Vector2(t * TILE) + Vector2(TILE, TILE) / 2.0


func _free(p: Vector2) -> bool:
	for corner: Vector2 in [
		Vector2(-HALF_BOX, -HALF_BOX),
		Vector2(HALF_BOX, -HALF_BOX),
		Vector2(-HALF_BOX, HALF_BOX),
		Vector2(HALF_BOX, HALF_BOX)
	]:
		if not IslandMap.walkable(Vector2i(((p + corner) / TILE).floor())):
			return false
	return true


func _nearest() -> int:
	var best := -1
	var best_d := REACH * TILE
	for i in _things.size():
		if not _present(_things[i]["kind"]):
			continue
		var d := player_pos.distance_to(_centre_of(_things[i]["pos"]))
		if d <= best_d:
			best_d = d
			best = i
	return best


func _near_kind() -> String:
	var i := _nearest()
	return _things[i]["kind"] if i >= 0 else ""


func _tomb_index() -> int:
	for i in _things.size():
		if _things[i]["kind"] == "tomb":
			return i
	return -1


func _tomb_pos() -> Vector2i:
	return _things[_tomb_index()]["pos"]


func _wasd() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	return v


# ---- showing it -------------------------------------------------------------------------


func _refresh() -> void:
	_camera.position = player_pos
	var d: Dictionary = GameState.data
	var inv: Dictionary = d["inventory"]
	var gear: Dictionary = d["gear"]
	var parts: Array[String] = []
	for kind: String in Forage.KINDS:
		if int(inv.get(kind, 0)) > 0:
			parts.append("%s %d" % [Forage.display_name(kind), inv[kind]])
	if int(inv.get("Crystal", 0)) > 0:
		parts.append("Crystal %d" % inv["Crystal"])
	_hud.text = (
		"%s %s\nStamina %d/%d   Coin %d   Pack: anchors %d  flares %d  rations %d   Finds %d\n%s"
		% [
			Calendar.describe(GameState.day(), GameState.half()),
			"The supply boat is in." if not GameState.boat_here().is_empty() else "",
			GameState.stamina(),
			int(d["stamina"]["max"]),
			GameState.coin(),
			gear["anchor"],
			gear["flare"],
			gear["ration"],
			d["finds"].size(),
			"  ".join(parts) if not parts.is_empty() else "Nothing gathered yet."
		]
	)
	_prompt.text = _prompt_text() + ("\n" + _message if _message != "" else "")
	# Grow the prompt upward so long lists stay on screen.
	_prompt.visible = _prompt.text != ""
	_prompt.reset_size()
	_prompt.position.y = 266 - _prompt.size.y
	queue_redraw()


func _prompt_text() -> String:
	var i := _nearest()
	if i < 0:
		return ""
	var thing: Dictionary = _things[i]
	var kind: String = thing["kind"]
	if PROMPTS.has(kind):
		return PROMPTS[kind]
	if kind == "trader":
		return _trader_prompt()
	if kind == "collector":
		return _collector_prompt()
	if kind == "bench":
		return _bench_prompt()
	return _plant_prompt(thing)


func _bench_prompt() -> String:
	var lines: Array[String] = []
	for k in Crafting.ORDER.size():
		var item: String = Crafting.ORDER[k]
		lines.append("%d %s (%s)" % [k + 1, Crafting.NAMES[item], Crafting.describe(item)])
	return "\n".join(lines)


func _plant_prompt(thing: Dictionary) -> String:
	var kind: String = thing["kind"]
	var ready_at := int(GameState.data["forage"].get(thing["id"], 0))
	var why := Forage.why_not(kind, ready_at, GameState.day(), GameState.half())
	var label := Forage.display_name(kind)
	if why != "":
		return "%s: %s" % [label, why]
	return "E: gather %s (%d stamina)" % [label, Forage.GATHER_COST]


func _visitor_greeting(kind: String) -> String:
	var here := GameState.boat_here()
	match kind:
		"trader":
			return "%s looks over your finds." % Boat.TRADERS[here["trader"]]["name"]
		"collector":
			var c: Dictionary = Boat.COLLECTORS[here["collector"]]
			return "%s collects for %s." % [c["name"], Finds.COLLECTIONS[c["collection"]]["name"]]
	return "The supply boat, moored for the day. It leaves at dawn."


func _trader_prompt() -> String:
	var trader: String = GameState.boat_here()["trader"]
	var lines: Array[String] = ["%s buys:" % Boat.TRADERS[trader]["name"]]
	var finds: Array = GameState.data["finds"]
	var listed := _listed_finds("")
	for k in listed.size():
		var f: Dictionary = finds[listed[k]]
		var keen := "  (keen!)" if Boat.likes(trader, f) else ""
		lines.append("%d %s: %d coin%s" % [k + 1, Finds.describe(f), Boat.offer(trader, f), keen])
	if listed.is_empty():
		lines.append("(You have no finds to sell.)")
	var crystals := int(GameState.data["inventory"].get("Crystal", 0))
	if Boat.crystal_offer(trader) > 0 and crystals > 0:
		lines.append("0 all %d crystals: %d coin each" % [crystals, Boat.crystal_offer(trader)])
	if Boat.sells_gear(trader):
		lines.append(
			(
				"Sells: Z anchor %d  X flare %d  C ration %d"
				% [
					Boat.GEAR_PRICES["anchor"],
					Boat.GEAR_PRICES["flare"],
					Boat.GEAR_PRICES["ration"]
				]
			)
		)
	return "\n".join(lines)


func _collector_prompt() -> String:
	var collection := _collection_here()
	var info: Dictionary = Finds.COLLECTIONS[collection]
	var m: Dictionary = GameState.data["museums"].get(
		collection, {"donated": [], "renown": 0, "complete": false}
	)
	var lines: Array[String] = [
		(
			"%s: %d of %d donated, renown %d%s"
			% [
				info["name"],
				m["donated"].size(),
				info["finds"].size(),
				m["renown"],
				"  (complete)" if m["complete"] else ""
			]
		)
	]
	var finds: Array = GameState.data["finds"]
	var listed := _listed_finds(collection)
	for k in listed.size():
		var f: Dictionary = finds[listed[k]]
		var have := "  (they have one)" if m["donated"].has(f["id"]) else ""
		lines.append("%d donate %s%s" % [k + 1, Finds.describe(f), have])
	if listed.is_empty():
		lines.append("Wants: %s" % ", ".join(info["finds"]))
	return "\n".join(lines)


func _draw() -> void:
	var size := IslandMap.size()
	var season := Calendar.season(GameState.day())
	var night := Calendar.is_night(GameState.half())
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			var c := _ground(IslandMap.char_at(p), season)
			if night:
				var dist := player_pos.distance_to(_centre_of(p)) / TILE
				var dark := clampf((dist - NIGHT_LIGHT) / NIGHT_FADE, 0.0, 1.0) * 0.85 + 0.1
				c = c.lerp(COLORS["night"], dark)
			draw_rect(Rect2(Vector2(p * TILE), Vector2(TILE, TILE)), c)
	for t in _things:
		_draw_thing(t, night)
	draw_rect(
		Rect2(player_pos - Vector2(HALF_BOX, HALF_BOX), Vector2(HALF_BOX, HALF_BOX) * 2),
		COLORS["player"]
	)


func _ground(ch: String, season: int) -> Color:
	if ch == "#":
		return SEASON_JUNGLE[season]
	if GROUND.has(ch):
		return COLORS[GROUND[ch]]
	return SEASON_GRASS[season]


func _draw_thing(t: Dictionary, night: bool) -> void:
	var dist := player_pos.distance_to(_centre_of(t["pos"])) / TILE
	if night and dist > NIGHT_LIGHT + NIGHT_FADE:
		return
	var o := Vector2(t["pos"] * TILE)
	var centre := o + Vector2(TILE, TILE) / 2.0
	var kind: String = t["kind"]
	match kind:
		"tent":
			draw_colored_polygon(
				PackedVector2Array([o + Vector2(8, 1), o + Vector2(15, 15), o + Vector2(1, 15)]),
				COLORS["tent"]
			)
		"bench":
			draw_rect(Rect2(o + Vector2(1, 5), Vector2(14, 6)), COLORS["bench"])
		"philius":
			draw_circle(centre + Vector2(0, 2), 5, COLORS["philius"])
			draw_rect(Rect2(o + Vector2(3, 1), Vector2(10, 3)), Color("3a2a1a"))
		"tomb":
			draw_rect(Rect2(o + Vector2(3, 2), Vector2(10, 14)), COLORS["tomb"])
		"boat":
			if _present("boat"):
				draw_rect(Rect2(o + Vector2(-8, 6), Vector2(32, 9)), COLORS["boat"])
				draw_colored_polygon(
					PackedVector2Array(
						[o + Vector2(8, -14), o + Vector2(20, 5), o + Vector2(8, 5)]
					),
					COLORS["sail"]
				)
		"trader", "collector":
			if _present(kind):
				draw_circle(centre + Vector2(0, 2), 5, COLORS[kind])
		_:
			var ready_at := int(GameState.data["forage"].get(t["id"], 0))
			var why := Forage.why_not(kind, ready_at, GameState.day(), GameState.half())
			var col: Color = COLORS[kind]
			if why == "":
				draw_circle(centre, 5, col)
			else:
				draw_arc(centre, 4, 0, TAU, 12, col.darkened(0.4), 1.5)
