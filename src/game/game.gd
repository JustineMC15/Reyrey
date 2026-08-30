extends Node


@onready var current_room: Node = $CurrentRoom
@onready var player: CharacterBody2D = $Player

var current_room_scene_path: String = ""


# Music assigned to each room.
# null = no music assigned yet.
#
# When you find a song, replace null with:
# preload("res://audio/music/your_song.ogg")
#
# Example:
# "res://src/rooms/room_02-valecourt-fields.tscn":
#     preload("res://audio/music/valecourt.ogg"),
var room_music: Dictionary = {
	"res://src/rooms/A0R1.tscn":
		preload("res://assets/sound/music/Medieval Rondo.ogg"),

	"res://src/rooms/A0R2.tscn":
		preload("res://assets/sound/music/Medieval Rondo.ogg"),

	"res://src/rooms/A1R1.tscn":
		preload("res://assets/sound/music/022815townbgm.ogg"),

	"res://src/rooms/A1R2.tscn":
		preload("res://assets/sound/music/022815townbgm.ogg"),

	"res://src/rooms/A1R3.tscn":
		preload("res://assets/sound/music/022815townbgm.ogg"),

	"res://src/rooms/A2R1.tscn": null,
	"res://src/rooms/A3R1.tscn": null,
	"res://src/rooms/A4R1.tscn": null,
	"res://src/rooms/A5R1.tscn": null,
	"res://src/rooms/A6R1.tscn": null,
	"res://src/rooms/A7R1.tscn": null,
	"res://src/rooms/A8R1.tscn": null,
	"res://src/rooms/A9R1.tscn": null,

	"res://src/rooms/S1.tscn": null,
	"res://src/rooms/S2.tscn": null,
	"res://src/rooms/S3.tscn": null,
	"res://src/rooms/S4.tscn": null,
	"res://src/rooms/S5.tscn": null,
	"res://src/rooms/S6.tscn": null,
	"res://src/rooms/S7.tscn": null,
	"res://src/rooms/S8.tscn": null,
	"res://src/rooms/S9.tscn": null,
	"res://src/rooms/S10.tscn": null,
	"res://src/rooms/S11.tscn": null,
	"res://src/rooms/S12.tscn": null,
	"res://src/rooms/S13.tscn": null,
	"res://src/rooms/S14.tscn": null,
	"res://src/rooms/S15.tscn": null,
	"res://src/rooms/S16.tscn": null,
	"res://src/rooms/S17.tscn": null,
}


# Area name assigned to each room.
#
# Multiple rooms can use the same area name.
# The area is only shown once per save file.
var room_area_names: Dictionary = {
	"res://src/rooms/A0R1.tscn": "Valecourt Capital",
	"res://src/rooms/A0R2.tscn": "Valecourt Capital",

	"res://src/rooms/A1R1.tscn": "Valecourt Fields",
	"res://src/rooms/A2R1.tscn": "Cathedral Undercroft",
	"res://src/rooms/A3R1.tscn": "Coastal Road",
	"res://src/rooms/A4R1.tscn": "Elven Reach",
	"res://src/rooms/A5R1.tscn": "Thalassar Canal City",
	"res://src/rooms/A6R1.tscn": "Aureth Bastion",
	"res://src/rooms/A7R1.tscn": "Sahra-Kel Canyons",
	"res://src/rooms/A8R1.tscn": "Icefields",
	"res://src/rooms/A9R1.tscn": "The Tower",
}


func _ready() -> void:
	add_to_group("game")

	var room_path: String = GameState.startup_room_path
	var checkpoint_to_spawn: String = GameState.startup_checkpoint_id

	GameState.startup_room_path = ""
	GameState.startup_checkpoint_id = ""

	if room_path == "":
		room_path = "res://src/rooms/A0R1.tscn"

	await load_room(room_path)

	await get_tree().process_frame

	if checkpoint_to_spawn != "":
		await position_player_at_checkpoint(checkpoint_to_spawn)
	else:
		await position_player_at_start()

	GameState.is_loading_save = false

	if not GameState.has_seen_story_beat("opening_cutscene"):
		await Cutscene.play(StoryContent.OPENING_LINES)
		GameState.mark_story_beat_seen("opening_cutscene")

	player.enable_world_interaction()

	LoadingScreen.hide_loading()

func load_room(scene_path: String) -> void:
	scene_path = ResourceUID.ensure_path(scene_path)

	if scene_path == "":
		push_error("Game: Invalid room path.")
		return

	player.disable_world_interaction()

	GameState.is_room_unloading = true

	# Remove the previous room.
	for child in current_room.get_children():
		child.queue_free()

	await get_tree().process_frame

	var err := ResourceLoader.load_threaded_request(scene_path)

	if err != OK:
		push_error("Game: Failed to start threaded load: " + scene_path)
		GameState.is_room_unloading = false
		return

	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break

		if status == ResourceLoader.THREAD_LOAD_FAILED \
		or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Game: Failed to load room: " + scene_path)
			GameState.is_room_unloading = false
			return

		await get_tree().process_frame

	var room_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene

	if room_scene == null:
		push_error("Game: Failed to load room: " + scene_path)
		GameState.is_room_unloading = false
		return

	# IMPORTANT:
	# Set the current room path BEFORE adding the room to the tree.
	current_room_scene_path = scene_path

	var new_room := room_scene.instantiate()

	current_room.add_child(new_room)

	await get_tree().process_frame

	GameState.is_room_unloading = false

	_apply_camera_bounds(new_room)

	var music_track: AudioStream = room_music.get(scene_path)

	if music_track != null:
		Music.play_music(music_track)

	#var area_name: String = room_area_names.get(scene_path, "")

	#if area_name != "" \
	#and not GameState.area_names_seen.get(area_name, false):
#
		#GameState.area_names_seen[area_name] = true
#
		#var area_title := get_node_or_null("AreaTitle")
#
		#if area_title != null:
			#area_title.show_area(area_name)

func get_current_room_scene_path() -> String:
	return current_room_scene_path


func position_player_at_start() -> void:
	var spawn_points := get_tree().get_nodes_in_group("player_spawn")

	if spawn_points.is_empty():
		push_error("Game: No player_spawn found.")
		return

	var spawn_point := spawn_points[0] as Node2D

	if spawn_point == null:
		push_error("Game: Invalid player_spawn node.")
		return

	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera:
		camera.position_smoothing_enabled = false

	player.global_position = spawn_point.global_position
	player.velocity = Vector2.ZERO

	# Force the camera to use the new player position immediately.
	if camera:
		camera.reset_smoothing()

	await get_tree().physics_frame

	if camera:
		camera.position_smoothing_enabled = true


func position_player_at_checkpoint(checkpoint_id: String) -> void:
	var checkpoints := get_tree().get_nodes_in_group("checkpoints")

	for checkpoint in checkpoints:
		if not checkpoint.has_method("get") \
		and not "checkpoint_id" in checkpoint:
			continue

		if checkpoint.checkpoint_id != checkpoint_id:
			continue

		var camera := player.get_node_or_null("Camera2D") as Camera2D

		if camera:
			camera.position_smoothing_enabled = false

		var spawn_point := checkpoint.get_node_or_null("SpawnPoint") as Node2D

		if spawn_point == null:
			push_error(
				"Game: Checkpoint has no SpawnPoint: "
				+ checkpoint.checkpoint_id
			)
			return

		player.global_position = spawn_point.global_position
		player.velocity = Vector2.ZERO

		# Immediately synchronize the camera to the new player position.
		if camera:
			camera.reset_smoothing()

		await get_tree().physics_frame

		if camera:
			camera.position_smoothing_enabled = true

		return

	push_error(
		"Game: Checkpoint ID not found: "
		+ checkpoint_id
	)


var current_room_camera_bounds: CameraBounds = null

func _apply_camera_bounds(room: Node) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		push_error("Game: Player has no Camera2D.")
		return

	var bounds := room.get_node_or_null("CameraBounds") as CameraBounds
	current_room_camera_bounds = bounds

	if bounds == null:
		camera.limit_enabled = false
		return

	var limits: Rect2i = bounds.get_limits()

	camera.limit_enabled = true
	camera.limit_left = limits.position.x
	camera.limit_top = limits.position.y
	camera.limit_right = limits.end.x
	camera.limit_bottom = limits.end.y

	camera.enabled = true
	camera.make_current()


func restore_room_camera_bounds() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return

	if current_room_camera_bounds == null:
		camera.limit_enabled = false
		return

	var limits: Rect2i = current_room_camera_bounds.get_limits()

	camera.limit_enabled = true
	camera.limit_left = limits.position.x
	camera.limit_top = limits.position.y
	camera.limit_right = limits.end.x
	camera.limit_bottom = limits.end.y
