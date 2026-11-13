extends Node2D
## Starts the game: loads the save if there is one, else starts a new game, then goes to the
## island (the overworld).


func _ready() -> void:
	if GameState.data.is_empty():
		if not (SaveService.has_save() and SaveService.load_game() == OK):
			GameState.new_game(randi())
	get_tree().change_scene_to_file.call_deferred("res://scenes/overworld/overworld.tscn")
