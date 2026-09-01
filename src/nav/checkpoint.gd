extends Node2D

@export var checkpoint_id: String = "checkpoint_01"
@export var room_name: String = ""

var player_inside := false
var activated := false
var prompt_tween: Tween

@onready var area: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var rest_prompt: Label = $RestPrompt
@onready var touch_sound: AudioStreamPlayer2D = $TouchSound
@onready var touch_effect: AnimatedSprite2D = $TouchEffect


func _ready() -> void:
	add_to_group("checkpoints")

	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

	rest_prompt.modulate.a = 0.0
	touch_effect.visible = false

	touch_effect.animation_finished.connect(_on_touch_effect_finished)

	var scene_path := _get_current_room_path()

	# Restore whether this checkpoint has previously been activated.
	if scene_path != "":
		if GameState.is_checkpoint_activated(scene_path, checkpoint_id):
			activated = true
			sprite.modulate = Color(1.2, 1.2, 1.0, 1.0)

	# Restore activated state after respawning/reloading the room.
	if GameState.has_checkpoint() \
	and GameState.checkpoint_id == checkpoint_id:
		activated = true
		sprite.modulate = Color(1.2, 1.2, 1.0, 1.0)


func _process(_delta: float) -> void:
	if player_inside and activated:
		if Input.is_action_just_pressed("interact"):
			rest()


func _on_area_entered(area_entered: Area2D) -> void:
	if not area_entered.is_in_group("player_detection"):
		return

	var player := area_entered.get_parent()

	if not player.is_in_group("player"):
		return

	GameState.enter_checkpoint_range()

	player_inside = true

	activate(player)
	_show_rest_prompt()


func _on_area_exited(area_exited: Area2D) -> void:
	if not area_exited.is_in_group("player_detection"):
		return

	GameState.exit_checkpoint_range()

	player_inside = false

	_hide_rest_prompt()

func activate(player: Node) -> void:
	var scene_path := _get_current_room_path()

	if scene_path == "":
		return


	if GameState.is_checkpoint_activated(
		scene_path,
		checkpoint_id
	):
		activated = true
		return

	activated = true

	GameState.activate_checkpoint(
		scene_path,
		checkpoint_id
	)

	GameState.set_checkpoint(
		scene_path,
		checkpoint_id,
		room_name
	)

	heal_player(player)

	touch_sound.play()
	touch_effect.visible = true
	touch_effect.play("touch")

	sprite.modulate = Color(1.2, 1.2, 1.0, 1.0)

func rest() -> void:
	if not player_inside:
		return

	if not GameState.can_trigger_gate():
		return

	var players := get_tree().get_nodes_in_group("player")

	if players.is_empty():
		return

	var player = players[0]

	player.lock_input()

	_hide_rest_prompt()

	var scene_path := _get_current_room_path()

	if scene_path == "":
		player.unlock_input()
		return

	# Make sure this checkpoint remains the spawn point.
	GameState.set_checkpoint(
		scene_path,
		checkpoint_id,
		room_name
	)
	await GameState.rest_at_checkpoint()

	player.unlock_input()

	SaveManager.save_game(SaveManager.current_slot)

func _get_current_room_path() -> String:
	var game := get_tree().get_first_node_in_group("game")

	if game == null:
		push_error("Checkpoint: Game instance not found.")
		return ""

	if not game.has_method("get_current_room_scene_path"):
		push_error(
			"Checkpoint: Game has no get_current_room_scene_path()."
		)
		return ""

	return game.get_current_room_scene_path()


func heal_player(player: Node) -> void:
	if player.has_method("restore_full_health"):
		player.restore_full_health()

	if player.has_method("restore_full_mp"):
		player.restore_full_mp()


func _show_rest_prompt() -> void:
	if prompt_tween:
		prompt_tween.kill()

	prompt_tween = create_tween()

	prompt_tween.tween_property(
		rest_prompt,
		"modulate:a",
		1.0,
		0.2
	)


func _hide_rest_prompt() -> void:
	if prompt_tween:
		prompt_tween.kill()

	prompt_tween = create_tween()

	prompt_tween.tween_property(
		rest_prompt,
		"modulate:a",
		0.0,
		0.15
	)


func _on_touch_effect_finished() -> void:
	if touch_effect.animation == "touch":
		touch_effect.visible = false
