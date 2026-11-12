extends CanvasLayer
## Gray-box debug overlay: shows the internal game state. Toggle with ` (backquote).
## Keep until the vertical slice is done (CLAUDE.md).

const Codec := preload("res://core/save_codec.gd")

var _label := Label.new()
var _panel := PanelContainer.new()


func _ready() -> void:
	layer = 100
	_panel.position = Vector2(4, 4)
	_panel.modulate = Color(1, 1, 1, 0.85)
	_label.add_theme_font_size_override("font_size", 6)
	_panel.add_child(_label)
	add_child(_panel)
	visible = false
	GameState.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_QUOTELEFT:
		visible = not visible
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_label.text = "DEBUG  (` to hide)\n" + Codec.encode(GameState.data)
