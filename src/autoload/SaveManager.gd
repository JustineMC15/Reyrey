extends Node

const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.json"

var current_slot: int = 1


# Area presets

const AREA_PRESETS := {
	0: "Tutorial",
	1: "Valecourt Fields",
	2: "Cathedral Undercroft",
	3: "Coastal Road",
	4: "Elven Reach",
	5: "Thalassar Canal City",
	6: "Aureth Bastion",
	7: "Sahra-Kel Canyons",
	8: "Icefields",
	9: "The Tower",
}


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

	if file == null:
		push_error("SaveManager: failed to open slot %d" % slot)
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: slot %d is corrupt" % slot)
		return

	current_slot = slot

	GameState.apply_save_data(parsed)
	GameState.prepare_loaded_game()

	get_tree().change_scene_to_file(
		"res://src/game/game.tscn"
	)


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


# Save slot summary

func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)

	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var checkpoint_room_name: String = parsed.get(
		"checkpoint_room_name",
		""
	)

	var area_id := get_area_id_from_room_code(
		checkpoint_room_name
	)

	var area_name := get_area_name(area_id)

	return {
		"area": area_name,
		"area_id": area_id,
		"timestamp": parsed.get("timestamp", ""),
		"checkpoint_scene_path": parsed.get(
			"checkpoint_scene_path",
			""
		),
	}


# Area lookup

func get_area_id_from_room_code(room_code: String) -> int:
	if room_code == "":
		return -1

	if not room_code.begins_with("A"):
		return -1

	var r_position := room_code.find("R")

	if r_position == -1:
		return -1

	var area_string := room_code.substr(
		1,
		r_position - 1
	)

	if not area_string.is_valid_int():
		return -1

	return int(area_string)


func get_area_name(area_id: int) -> String:
	return AREA_PRESETS.get(
		area_id,
		"Unknown Area"
	)


func get_area_name_from_room_code(room_code: String) -> String:
	var area_id := get_area_id_from_room_code(room_code)

	return get_area_name(area_id)


# Settings

func save_settings(master_volume_linear: float) -> void:
	var data := {
		"master_volume": master_volume_linear
	}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_settings_and_apply() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)

	if file == null:
		return

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
