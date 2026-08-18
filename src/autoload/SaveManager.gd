extends Node

const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.json"

var current_slot: int = 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_load_settings_and_apply()

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func save_game(slot: int) -> void:
	var data := GameState.get_save_data()
	data["timestamp"] = Time.get_datetime_string_from_system()

	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("SaveManager: failed to open slot %d for writing" % slot)

func load_game(slot: int) -> void:
	if not has_save(slot):
		push_error("SaveManager: no save in slot %d" % slot)
		return

	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: slot %d is corrupt" % slot)
		return

	current_slot = slot
	GameState.apply_save_data(parsed)
	await GameState.load_from_save(parsed.get("checkpoint_scene_path", ""))

func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))

func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return {
		"room_name": parsed.get("checkpoint_room_name", "Unknown"),
		"shrine_count": parsed.get("shrine_count", 0),
		"timestamp": parsed.get("timestamp", ""),
		"checkpoint_scene_path": parsed.get("checkpoint_scene_path", ""),
	}

# --- Settings (global, not per-slot) ---

func save_settings(master_volume_linear: float) -> void:
	var data := {"master_volume": master_volume_linear}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_settings_and_apply() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var vol: float = parsed.get("master_volume", 1.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(clampf(vol, 0.0001, 1.0))
	)
