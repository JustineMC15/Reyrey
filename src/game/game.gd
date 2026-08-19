extends Node

@onready var current_room: Node = $CurrentRoom
@onready var player: CharacterBody2D = $Player

var current_room_scene_path: String = ""


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


func load_room(scene_path: String) -> void:
	scene_path = ResourceUID.ensure_path(scene_path)

	player.disable_world_interaction()

	for child in current_room.get_children():
		child.queue_free()

	await get_tree().process_frame

	var room_scene := load(scene_path) as PackedScene

	if room_scene == null:
		push_error("Game: Failed to load room: " + scene_path)
		player.enable_world_interaction()
		return

	var room := room_scene.instantiate()
	current_room.add_child(room)

	current_room_scene_path = scene_path

	await get_tree().process_frame

	player.enable_world_interaction()


func get_current_room_scene_path() -> String:
	return current_room_scene_path


func position_player_at_start() -> void:
	var spawn_points := get_tree().get_nodes_in_group("player_spawn")

	if spawn_points.is_empty():
		push_error("Game: No player_spawn found.")
		player.enable_world_interaction()
		return

	var spawn_point: Node2D = spawn_points[0]

	player.global_position = spawn_point.global_position
	player.velocity = Vector2.ZERO


func position_player_at_checkpoint(checkpoint_id: String) -> void:
	var checkpoints := get_tree().get_nodes_in_group("checkpoints")

	for checkpoint in checkpoints:
		if checkpoint.checkpoint_id == checkpoint_id:
			var camera := player.get_node_or_null("Camera2D")

			if camera:
				camera.position_smoothing_enabled = false

			var spawn_point := checkpoint.get_node_or_null("SpawnPoint")

			if spawn_point == null:
				push_error(
					"Game: Checkpoint has no SpawnPoint: "
					+ checkpoint.checkpoint_id
				)
				return

			player.global_position = spawn_point.global_position
			player.velocity = Vector2.ZERO

			await get_tree().physics_frame

			if camera:
				camera.reset_smoothing()

			return

	push_error("Game: Checkpoint ID not found: " + checkpoint_id)
