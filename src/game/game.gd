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
# "res://src/Rooms/room_02-valecourt-fields.tscn":
#     preload("res://audio/music/valecourt.ogg"),
var room_music: Dictionary = {
	"res://src/Rooms/room_01-tutorial.tscn":
		preload("res://assets/sound/music/Medieval Rondo.ogg"),

	"res://src/Rooms/room_02-valecourt-fields.tscn":
		preload("res://assets/sound/music/Medieval Rondo.ogg"),

	"res://src/Rooms/room_03-cathedral-undercroft.tscn": null,
	"res://src/Rooms/room_04-coastal-road.tscn": null,
	"res://src/Rooms/room_05-elven-reach.tscn": null,
	"res://src/Rooms/room_06-thalassar-canal-city.tscn": null,
	"res://src/Rooms/room_07-aureth-bastion.tscn": null,
	"res://src/Rooms/room_08-sahra-kel-canyons.tscn": null,
	"res://src/Rooms/room_09-icefields.tscn": null,
	"res://src/Rooms/room_10-the-tower.tscn": null,

	"res://src/Rooms/shrine_01.tscn": null,
	"res://src/Rooms/shrine_02.tscn": null,
	"res://src/Rooms/shrine_03.tscn": null,
	"res://src/Rooms/shrine_04.tscn": null,
	"res://src/Rooms/shrine_05.tscn": null,
	"res://src/Rooms/shrine_06.tscn": null,
	"res://src/Rooms/shrine_07.tscn": null,
	"res://src/Rooms/shrine_08.tscn": null,
	"res://src/Rooms/shrine_09.tscn": null,
	"res://src/Rooms/shrine_10.tscn": null,
	"res://src/Rooms/shrine_11.tscn": null,
	"res://src/Rooms/shrine_12.tscn": null,
	"res://src/Rooms/shrine_13.tscn": null,
	"res://src/Rooms/shrine_14.tscn": null,
	"res://src/Rooms/shrine_15.tscn": null,
	"res://src/Rooms/shrine_16.tscn": null,
	"res://src/Rooms/shrine_17.tscn": null,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")

	var room_path: String = GameState.startup_room_path
	var checkpoint_to_spawn: String = GameState.startup_checkpoint_id

	GameState.startup_room_path = ""
	GameState.startup_checkpoint_id = ""

	if room_path == "":
		room_path = "res://src/Rooms/room_01-tutorial.tscn"

	await load_room(room_path)

	await get_tree().process_frame

	if checkpoint_to_spawn != "":
		await position_player_at_checkpoint(checkpoint_to_spawn)
	else:
		await position_player_at_start()

	player.enable_world_interaction()


func load_room(scene_path: String) -> void:
	scene_path = ResourceUID.ensure_path(scene_path)

	if scene_path == "":
		push_error("Game: Invalid room path.")
		return

	player.disable_world_interaction()

	# Remove the previous room.
	for child in current_room.get_children():
		child.queue_free()

	await get_tree().process_frame

	var room_scene := load(scene_path) as PackedScene

	if room_scene == null:
		push_error("Game: Failed to load room: " + scene_path)
		return

	# IMPORTANT:
	# Set the current room path BEFORE adding the room to the tree.
	# The room's _ready() functions can run immediately after add_child().
	current_room_scene_path = scene_path

	var new_room := room_scene.instantiate()

	current_room.add_child(new_room)

	# Wait until the new room has entered the tree and its children
	# have initialized before looking for CameraBounds.
	await get_tree().process_frame

	# Apply the new room's camera limits before the player is positioned.
	_apply_camera_bounds(new_room)

	# Get the music assigned to this room.
	var music_track: AudioStream = room_music.get(scene_path)

	# Only change music when this room has a track assigned.
	if music_track != null:
		Music.play_music(music_track)


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


func _apply_camera_bounds(room: Node) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		push_error("Game: Player has no Camera2D.")
		return

	var bounds := room.get_node_or_null("CameraBounds") as CameraBounds

	if bounds == null:
		camera.limit_enabled = false
		return

	camera.limit_enabled = true

	camera.limit_left = bounds.limit_left
	camera.limit_top = bounds.limit_top
	camera.limit_right = bounds.limit_right
	camera.limit_bottom = bounds.limit_bottom

	# Make sure this is the camera currently controlling the viewport.
	camera.enabled = true
	camera.make_current()
