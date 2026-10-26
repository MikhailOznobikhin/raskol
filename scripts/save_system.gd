extends RefCounted
## Сохранения: чтение/запись user://save.json.

class_name SaveSystem

const PATH := "user://save.json"

static func save_game(state: Dictionary) -> void:
	write(state)

static func load_game() -> Dictionary:
	return read()

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

static func write(state: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(state))
	f.close()

static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if data is Dictionary:
		return data
	return {}
