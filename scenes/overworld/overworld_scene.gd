extends Node2D
## Gray-box overworld (FEEL_OVERWORLD.md): the island around camp. Calm and real-time; no clock
## runs (D35). Walking is free, gathering costs stamina, and time only moves when you rest at
## the tent or go into the tomb.
##
## WASD/arrows walk, E use (tent, workbench, Professor Philius, plants, the tomb). Number keys
## act on what you stand by: craft at the workbench, sell to a trader, donate to a collector,
## put finds on the shelf (0 takes one down), build from the camp plans. J opens the journal,
## Esc the menu. F5 saves (resting saves too). ` shows the debug overlay.

const IslandMap := preload("res://core/overworld/island_map.gd")
const Calendar := preload("res://core/calendar.gd")
const Forage := preload("res://core/overworld/forage.gd")
const Crafting := preload("res://core/overworld/crafting.gd")
const Philius := preload("res://core/overworld/philius.gd")
const Boat := preload("res://core/boat.gd")
const Finds := preload("res://core/finds.gd")
const Camp := preload("res://core/overworld/camp.gd")
const Story := preload("res://core/overworld/story.gd")
const DebugOverlay := preload("res://scenes/debug/debug_overlay.gd")
const Art := preload("res://scenes/art.gd")

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
	"shelf": Color("b08850"),
	"plans": Color("e8e0c8"),
}
## Season names in art file names (RENDERING_CONTRACT.md section 5).
const SEASON_ART: Array[String] = ["dry", "rains", "bloom", "mists"]
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
## A full-screen page over the island: the journal or the menu. Walking stops while it's open.
var _page := Label.new()
## "", "journal" or "menu".
var _page_kind := ""


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
	var page_bg := StyleBoxFlat.new()
	page_bg.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	page_bg.set_content_margin_all(10)
	_page.add_theme_stylebox_override("normal", page_bg)
	_page.add_theme_font_size_override("font_size", 8)
	_page.position = Vector2(20, 14)
	_page.size = Vector2(440, 242)
	_page.visible = false
	_hud_layer.add_child(_page)
	add_child(_hud_layer)
	add_child(DebugOverlay.new())
	GameState.changed.connect(_refresh)
	if not GameState.expedition_pack.is_empty() or GameState.back_from_tomb:
		GameState.back_from_tomb = false
		player_pos = _centre_of(_tomb_pos() + Vector2i.DOWN)
	_refresh()


func _process(delta: float) -> void:
	queue_redraw()  # the sea moves
	if _page_kind != "":
		return
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
	if _page_kind != "" or key.keycode in [KEY_ESCAPE, KEY_J]:
		_page_key(key.keycode)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
			_refresh()
		return
	match key.keycode:
		KEY_E:
			_use()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_number(key.keycode - KEY_1)
		KEY_0:
			match _near_kind():
				"trader":
					_message = GameState.sell_crystals()
				"shelf":
					_message = GameState.take_down()
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
		"shelf":
			var finds := _listed_finds("")
			if n < finds.size():
				_message = GameState.display(finds[n])
		"plans":
			if n < Camp.ORDER.size():
				var id: String = Camp.ORDER[n]
				var why := GameState.build(id)
				_message = "Built: %s." % Camp.UPGRADES[id]["name"] if why == "" else why


## Keys while the journal or the menu is open (or opening them).
func _page_key(keycode: int) -> void:
	if _page_kind == "menu":
		match keycode:
			KEY_ENTER, KEY_KP_ENTER:
				SaveService.save_game()
				get_tree().change_scene_to_file("res://scenes/title/title.tscn")
			KEY_Q:
				SaveService.save_game()
				get_tree().quit()
			KEY_ESCAPE:
				_page_kind = ""
		return
	if _page_kind == "journal":
		if keycode in [KEY_ESCAPE, KEY_J]:
			_page_kind = ""
		return
	_page_kind = "journal" if keycode == KEY_J else "menu"


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
		"shelf", "plans":
			_message = ""
		"philius":
			_message = _philius_says()
			_philius_talks += 1
		"tomb":
			_use_tomb()
		"trader", "collector", "boat":
			_message = _visitor_greeting(thing["kind"])
		_:
			var why := GameState.gather(thing["id"], thing["kind"])
			_message = ("Gathered %s." % Forage.display_name(thing["kind"]) if why == "" else why)


## The story first (D46), then a reminder of what he's waiting for, then idle chatter.
func _philius_says() -> String:
	var story := GameState.story_talk()
	if not story.is_empty():
		return (
			"Professor Philius:\n"
			+ "\n".join(story.map(func(l: String) -> String: return '"%s"' % l))
		)
	var line := Story.reminder(GameState.story_stage()) if _philius_talks % 3 == 0 else ""
	if line == "":
		var season: String = Calendar.SEASONS[Calendar.season(GameState.day())]
		line = Philius.line(season, Calendar.is_night(GameState.half()), _philius_talks)
	return 'Professor Philius: "%s"' % line


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
	# Save first: quitting the game mid-expedition comes back to this moment.
	SaveService.save_game()
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
		(
			"%s %s   J journal  Esc menu\n"
			+ "Stamina %d/%d   Coin %d   Pack: anchors %d  flares %d  rations %d   Finds %d\n%s"
		)
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
	_page.visible = _page_kind != ""
	_page.text = _journal_text() if _page_kind == "journal" else _menu_text()
	_prompt.text = _prompt_text() + ("\n" + _message if _message != "" else "")
	# Grow the prompt upward so long lists stay on screen.
	_prompt.visible = _prompt.text != "" and _page_kind == ""
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
	var by_kind := {
		"trader": _trader_prompt,
		"collector": _collector_prompt,
		"bench": _bench_prompt,
		"shelf": _shelf_prompt,
		"plans": _plans_prompt,
	}
	if by_kind.has(kind):
		return (by_kind[kind] as Callable).call()
	return _plant_prompt(thing)


func _shelf_prompt() -> String:
	var shelf := GameState.shelf()
	var lines: Array[String] = [
		(
			"Display shelf, %d of %d: tunnel hints are right %d%% of the time"
			% [shelf.size(), Camp.SHELF_SLOTS, roundi(Camp.hint_accuracy(shelf.size()) * 100)]
		)
	]
	for f: Dictionary in shelf:
		lines.append("  " + Finds.describe(f))
	var finds: Array = GameState.data["finds"]
	var listed := _listed_finds("")
	if shelf.size() < Camp.SHELF_SLOTS:
		for k in listed.size():
			lines.append("%d put out %s" % [k + 1, Finds.describe(finds[listed[k]])])
	if not shelf.is_empty():
		lines.append("0 take down the %s" % shelf[-1]["id"])
	return "\n".join(lines)


func _plans_prompt() -> String:
	var lines: Array[String] = ["Camp plans (you have %d coin):" % GameState.coin()]
	for k in Camp.ORDER.size():
		var id: String = Camp.ORDER[k]
		var u: Dictionary = Camp.UPGRADES[id]
		var state := "built" if GameState.built().has(id) else "%d coin" % u["cost"]
		lines.append("%d %s (%s): %s" % [k + 1, u["name"], state, u["about"]])
	return "\n".join(lines)


func _menu_text() -> String:
	return (
		"\n"
		. join(
			[
				"PAUSED",
				"",
				"Esc   back to the island",
				"Enter save and go to the title screen",
				"Q     save and quit",
			]
		)
	)


## The journal (D45): every find you know of, by collection, and Philius's notes.
func _journal_text() -> String:
	var d: Dictionary = GameState.data
	var seen: Dictionary = d["journal"]["seen"]
	var lines: Array[String] = ["JOURNAL   (J or Esc closes)", ""]
	for c: String in Finds.COLLECTIONS:
		var info: Dictionary = Finds.COLLECTIONS[c]
		var m: Dictionary = d["museums"].get(c, {"donated": [], "renown": 0})
		var names: Array[String] = []
		for id: String in info["finds"]:
			var where := ""
			if m["donated"].has(id):
				where = " (donated)"
			elif GameState.shelf().any(func(f: Dictionary) -> bool: return f["id"] == id):
				where = " (on the shelf)"
			names.append((id + where) if seen.has(id) else "???")
		lines.append("%s, renown %d: %s" % [info["name"], m["renown"], ", ".join(names)])
	lines.append("")
	var built: Array[String] = []
	for id: String in Camp.ORDER:
		if GameState.built().has(id):
			built.append(Camp.UPGRADES[id]["name"])
	lines.append("Camp: " + (", ".join(built) if not built.is_empty() else "nothing built yet"))
	lines.append(
		"Expeditions: %d   Coin: %d" % [int(d["flags"].get("expeditions", 0)), GameState.coin()]
	)
	lines.append("")
	lines.append("Notes:")
	var notes: Array = d["journal"]["notes"]
	if notes.is_empty():
		lines.append("  Nothing yet. Philius says to go into the tomb and come back out.")
	for n: String in notes:
		lines.append("  - " + n)
	return "\n".join(lines)


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
			_draw_ground(Vector2i(x, y), season)
	# Y-sorted layer (contract section 3): things and the player by the y of their feet.
	var sorted: Array = []
	for t in _things:
		sorted.append([float(t["pos"].y * TILE + TILE), t])
	sorted.append([player_pos.y + HALF_BOX, {}])
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in sorted:
		if (item[1] as Dictionary).is_empty():
			_draw_player()
		else:
			_draw_thing(item[1], night)
	if night:
		_draw_night(size)


## A ground tile: art if there is some (D49), else the gray-box colour.
func _draw_ground(p: Vector2i, season: int) -> void:
	var ch := IslandMap.char_at(p)
	var rect := Rect2(Vector2(p * TILE), Vector2(TILE, TILE))
	var art := _ground_art(ch, p, season)
	var t := Art.tex(art) if art != "" else null
	if t != null:
		draw_texture(t, rect.position)
	else:
		draw_rect(rect, _ground(ch, season))


func _ground_art(ch: String, p: Vector2i, season: int) -> String:
	var season_name: String = SEASON_ART[season]
	match ch:
		"#":
			# Show the front of the jungle where open ground is below it.
			var face := IslandMap.char_at(p + Vector2i.DOWN) != "#"
			return "island/jungle_%s%s" % ["face_" if face else "", season_name]
		"~", "B":
			return "island/sea_%d" % (int(Time.get_ticks_msec() / 250.0 + p.x) % 4)
		"=":
			return "island/jetty"
		",", "@", "V", "C":
			return "island/sand"
	return "island/grass_" + season_name


## Night (D35): only the lamp lights the way, drawn over the art (contract section 3).
func _draw_night(size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			var dist := player_pos.distance_to(_centre_of(p)) / TILE
			var dark := clampf((dist - NIGHT_LIGHT) / NIGHT_FADE, 0.0, 1.0) * 0.85 + 0.1
			var c: Color = COLORS["night"]
			c.a = dark
			draw_rect(Rect2(Vector2(p * TILE), Vector2(TILE, TILE)), c)


func _draw_player() -> void:
	if not Art.draw_feet(self, "characters/player", player_pos + Vector2(0, HALF_BOX)):
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


## The art name for a thing, or "" if it has none (or isn't here now).
func _thing_art(t: Dictionary) -> String:
	var kind: String = t["kind"]
	match kind:
		"tent", "bench", "plans", "boat":
			return "camp/" + kind
		"tomb":
			return "camp/tomb_door"
		"shelf":
			return "camp/shelf_%d" % mini(GameState.shelf().size(), Camp.SHELF_SLOTS)
		"philius", "trader", "collector":
			return "characters/" + kind
	if Forage.KINDS.has(kind):
		var ready_at := int(GameState.data["forage"].get(t["id"], 0))
		var why := Forage.why_not(kind, ready_at, GameState.day(), GameState.half())
		return "plants/%s%s" % [kind, "" if why == "" else "_picked"]
	return ""


func _draw_thing(t: Dictionary, night: bool) -> void:
	var dist := player_pos.distance_to(_centre_of(t["pos"])) / TILE
	if night and dist > NIGHT_LIGHT + NIGHT_FADE:
		return
	var kind: String = t["kind"]
	if not _present(kind):
		return
	var art := _thing_art(t)
	if art.begins_with("characters/"):
		if Art.draw_feet(self, art, _centre_of(t["pos"]) + Vector2(0, 6)):
			return
	elif art != "" and Art.draw_on_tile(self, art, t["pos"], TILE):
		return
	_draw_thing_shape(t)


## The gray-box shape for a thing with no art yet.
func _draw_thing_shape(t: Dictionary) -> void:
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
		"shelf":
			draw_rect(Rect2(o + Vector2(1, 2), Vector2(14, 12)), COLORS["shelf"])
		"plans":
			draw_rect(Rect2(o + Vector2(3, 2), Vector2(10, 12)), COLORS["plans"])
		"philius":
			draw_circle(centre + Vector2(0, 2), 5, COLORS["philius"])
			draw_rect(Rect2(o + Vector2(3, 1), Vector2(10, 3)), Color("3a2a1a"))
		"tomb":
			draw_rect(Rect2(o + Vector2(3, 2), Vector2(10, 14)), COLORS["tomb"])
		"boat":
			draw_rect(Rect2(o + Vector2(-8, 6), Vector2(32, 9)), COLORS["boat"])
			draw_colored_polygon(
				PackedVector2Array([o + Vector2(8, -14), o + Vector2(20, 5), o + Vector2(8, 5)]),
				COLORS["sail"]
			)
		"trader", "collector":
			draw_circle(centre + Vector2(0, 2), 5, COLORS[kind])
		_:
			var ready_at := int(GameState.data["forage"].get(t["id"], 0))
			var why := Forage.why_not(kind, ready_at, GameState.day(), GameState.half())
			var col: Color = COLORS[kind]
			if why == "":
				draw_circle(centre, 5, col)
			else:
				draw_arc(centre, 4, 0, TAU, 12, col.darkened(0.4), 1.5)
