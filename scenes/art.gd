extends RefCounted
## Finds the art for a name like "tomb/floor" (D49, RENDERING_CONTRACT.md section 8): real art
## in res://art/ first, then the code-made placeholder in res://art/placeholder/, else null, and
## the scene draws its gray-box shape instead. Drop a real PNG in art/ and it wins, no code change.

const ROOTS: Array[String] = ["res://art/", "res://art/placeholder/"]

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var found: Texture2D = null
	for root in ROOTS:
		var path := root + name + ".png"
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_cache[name] = found
	return found


## Draws a sprite with its feet (bottom centre, contract section 2) at feet. Returns false if
## there's no art, so the caller can draw its shape.
static func draw_feet(ci: CanvasItem, name: String, feet: Vector2) -> bool:
	var t := tex(name)
	if t == null:
		return false
	var s := t.get_size()
	var foot_row := 30.0 if s.y == 32.0 and s.x == 32.0 else s.y
	ci.draw_texture(t, (feet - Vector2(s.x / 2.0, foot_row)).round())
	return true


## Draws a tile-anchored sprite: its bottom row on tile p's bottom, centred across the tile, so
## tall props overhang upward and wide ones overhang to both sides.
static func draw_on_tile(ci: CanvasItem, name: String, p: Vector2i, tile: int) -> bool:
	var t := tex(name)
	if t == null:
		return false
	var s := t.get_size()
	var at := Vector2(p * tile) + Vector2((tile - s.x) / 2.0, tile - s.y)
	ci.draw_texture(t, at.round())
	return true
