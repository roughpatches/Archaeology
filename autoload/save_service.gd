extends Node
## Reads and writes the save file. One slot for now.

const Codec := preload("res://core/save_codec.gd")
const SAVE_PATH := "user://save.json"


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(Codec.encode(GameState.snapshot()))
	return OK


func load_game(path: String = SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var decoded := Codec.decode(FileAccess.get_file_as_string(path))
	if decoded.is_empty():
		return ERR_PARSE_ERROR
	return OK if GameState.load_from(decoded) else ERR_INVALID_DATA
