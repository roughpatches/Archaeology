extends Node2D
## Starts the game at the title screen.


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")
