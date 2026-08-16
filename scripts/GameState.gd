extends Node

var abilities: Dictionary = {
	"double_jump": false,
	"dash": false,
}

# --- Persistent Player Stats ---
var max_mp: int = 6
var current_mp: int = 6

# --- Room / Gate transition state ---
var pending_spawn_gate_id: String = ""
var _transition_lock: bool = false
var checkpoint_scene_path: String = ""
var checkpoint_id: String = ""
var checkpoint_room_name: String = ""
var checkpoint_activated: bool = false
var activated_checkpoints: Dictionary = {}


# --- Fade overlay, built in code so you don't need a separate scene ---
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
const FADE_DURATION := 0.25


# --- Star Shrines ---
var shrine_count: int = 0
var claimed_shrines: Dictionary = {}

const SHRINE_MP_GAINS: Array[int] = [
	3, 3, 3, 2, 2,
	2, 2, 2, 2, 1,
	1, 1, 1, 1, 1,
	1, 1
]

func is_shrine_claimed(shrine_id: String) -> bool:
	return claimed_shrines.has(shrine_id)


func claim_shrine(
	shrine_id: String,
	player: Node,
	abandonment_text: String
) -> void:
	if is_shrine_claimed(shrine_id):
		return

	if shrine_count >= SHRINE_MP_GAINS.size():
		return

	claimed_shrines[shrine_id] = true

	var gain := SHRINE_MP_GAINS[shrine_count]
	shrine_count += 1

	# Permanently increase maximum MP.
	max_mp += gain

	# Star Shrines fully restore MP.
	current_mp = max_mp

	print("SHRINE CLAIMED: ", shrine_id)
	print("MP GAIN: ", gain)
	print("GAMESTATE MAX MP: ", max_mp)
	print("GAMESTATE CURRENT MP: ", current_mp)

	# Apply the new maximum AND restore MP to full.
	if player:
		player.max_mp = max_mp
		player.mp = current_mp
		player.mp_changed.emit(player.mp, player.max_mp)

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	await _run_shrine_claim_sequence(
		player,
		gain,
		abandonment_text
	)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false

func _run_shrine_claim_sequence(
	player: Node,
	gain: int,
	abandonment_text: String
) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	# Dark overlay
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	# Center everything
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.modulate.a = 0.0
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# Main shrine text
	var title := Label.new()
	title.text = abandonment_text
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# MP increase text
	var gain_text := Label.new()
	gain_text.text = "Maximum MP increased by " + str(gain)
	gain_text.add_theme_font_size_override("font_size", 24)
	gain_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gain_text)

	# Continue prompt
	var prompt := Label.new()
	prompt.text = "Press Enter / Space to continue"
	prompt.modulate.a = 0.6
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	# Player glow
	var player_glow: Tween

	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")

		player_glow = create_tween().set_loops()

		player_glow.tween_property(
			sprite,
			"modulate",
			Color(2, 2, 1.4, 1),
			0.4
		)

		player_glow.tween_property(
			sprite,
			"modulate",
			Color.WHITE,
			0.4
		)

	# Fade in
	var fade_in := create_tween()

	fade_in.tween_property(
		dim,
		"color:a",
		0.85,
		0.4
	)

	fade_in.parallel().tween_property(
		vbox,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_in.finished

	# Prevent the same E/Enter press from instantly closing it
	await get_tree().create_timer(0.2).timeout

	# Wait for Enter or Space
	while not (
		Input.is_action_just_pressed("ui_accept")
	):
		await get_tree().process_frame

	# Stop player glow
	if player_glow:
		player_glow.kill()

		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	# Fade out
	var fade_out := create_tween()

	fade_out.tween_property(
		dim,
		"color:a",
		0.0,
		0.3
	)

	fade_out.parallel().tween_property(
		vbox,
		"modulate:a",
		0.0,
		0.3
	)

	await fade_out.finished

	layer.queue_free()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_overlay()


func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

# --- Room transition ---
func can_trigger_gate() -> bool:
	return not _transition_lock


func go_to_room(
	target_scene_path: String,
	target_gate_id: String
) -> void:
	if _transition_lock:
		return

	_transition_lock = true
	pending_spawn_gate_id = target_gate_id
	_fade_out_and_load(target_scene_path)


func _fade_out_and_load(target_scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		FADE_DURATION
	)

	await tween.finished

	get_tree().change_scene_to_file(target_scene_path)

	await get_tree().process_frame
	await get_tree().process_frame

	_on_new_room_ready()


func _on_new_room_ready() -> void:
	if pending_spawn_gate_id != "":
		_position_player_at_gate()
	elif checkpoint_id != "":
		_position_player_at_checkpoint()

	_fade_in()


func _position_player_at_gate() -> void:
	if pending_spawn_gate_id != "":
		var players := get_tree().get_nodes_in_group("player")
		var gates := get_tree().get_nodes_in_group("gates")

		if not players.is_empty():
			var player = players[0]

			for gate in gates:
				if gate.gate_id == pending_spawn_gate_id:
					player.global_position = gate.global_position
					break

		pending_spawn_gate_id = ""


func _position_player_at_checkpoint() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var checkpoints := get_tree().get_nodes_in_group("checkpoints")

	if players.is_empty():
		print("RESPAWN ERROR: No player found")
		return

	if checkpoints.is_empty():
		print("RESPAWN ERROR: No checkpoints found")
		return

	var player = players[0]

	for checkpoint in checkpoints:
		if checkpoint.checkpoint_id == checkpoint_id:
			print("RESPAWNING AT CHECKPOINT: ", checkpoint_id)
			player.global_position = checkpoint.global_position + Vector2(0, 70)
			return

	print("RESPAWN ERROR: Checkpoint ID not found: ", checkpoint_id)


func _fade_out_and_reload_current_scene() -> void:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		_transition_lock = false
		return

	_fade_out_and_load(current_scene.scene_file_path)


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		FADE_DURATION
	)

	await tween.finished

	_transition_lock = false


func rest_fade() -> void:
	var fade_out := create_tween()

	fade_out.tween_property(
		_fade_rect,
		"color:a",
		0.75,
		0.25
	)

	await fade_out.finished

	# Small pause while the player "rests"
	await get_tree().create_timer(0.15).timeout

	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		0.35
	)

	await fade_in.finished


# --- Ability system ---
func unlock_ability(ability_id: String) -> void:
	abilities[ability_id] = true


func has_ability(ability_id: String) -> bool:
	return abilities.get(ability_id, false)


var ability_data: Dictionary = {
	"double_jump": {
		"name": "Spark Flame",
		"tin_text": "Combustion. Whoever wrote this world's laws decided that flame needs something to eat before it's allowed to exist. No exceptions, not even for me. I can stop a heart, I can stop a star, and I still have to feed the fire before it will hold you up. Pathetic economy. Eternity doesn't need to be fed. I checked.",
		"reynauld_text": "It kicks like a mule and smells like my eyebrows. Effective, though. I've decided not to ask what it's burning. Whatever it is, it isn't coin, and that's the only ingredient I ever worry about running out of.",
	},
	"dash": {
		"name": "Holy Lance",
		"tin_text": "...",
		"reynauld_text": "...",
	},
}


signal ability_claimed(ability_id)


func claim_ability(
	ability_id: String,
	player: Node,
	icon: Texture2D = null
) -> void:
	if has_ability(ability_id):
		return

	_transition_lock = true

	if player and player.has_method("lock_input"):
		player.lock_input()

	_run_claim_sequence(ability_id, player, icon)


func _run_claim_sequence(
	ability_id: String,
	player: Node,
	icon: Texture2D
) -> void:
	var data: Dictionary = ability_data.get(ability_id, {})

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.modulate.a = 0.0
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(96, 96)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)

		var pulse := create_tween().set_loops()
		pulse.tween_property(
			icon_rect,
			"scale",
			Vector2(1.15, 1.15),
			0.6
		).set_trans(Tween.TRANS_SINE)

		pulse.tween_property(
			icon_rect,
			"scale",
			Vector2(1.0, 1.0),
			0.6
		)

	var title := Label.new()
	title.text = data.get("name", ability_id.capitalize()) + " Claimed"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for key in ["tin_text", "reynauld_text"]:
		if data.has(key):
			var line := Label.new()
			line.text = data[key]
			line.autowrap_mode = TextServer.AUTOWRAP_WORD
			line.custom_minimum_size = Vector2(760, 0)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(line)

	var prompt := Label.new()
	prompt.text = "Press Enter / Space to continue"
	prompt.modulate.a = 0.6
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	# Charge pulse on the player sprite while the ceremony plays
	var player_glow: Tween

	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")

		player_glow = create_tween().set_loops()

		player_glow.tween_property(
			sprite,
			"modulate",
			Color(2, 2, 1.4, 1),
			0.4
		)

		player_glow.tween_property(
			sprite,
			"modulate",
			Color.WHITE,
			0.4
		)

	var fade_in := create_tween()

	fade_in.tween_property(
		dim,
		"color:a",
		0.85,
		0.4
	)

	fade_in.parallel().tween_property(
		vbox,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_in.finished

	await get_tree().create_timer(0.2).timeout

	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

	if player_glow:
		player_glow.kill()

		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	var fade_out := create_tween()

	fade_out.tween_property(
		dim,
		"color:a",
		0.0,
		0.3
	)

	fade_out.parallel().tween_property(
		vbox,
		"modulate:a",
		0.0,
		0.3
	)

	await fade_out.finished

	layer.queue_free()

	unlock_ability(ability_id)

	if player and player.has_method("unlock_input"):
		player.unlock_input()

	_transition_lock = false
	ability_claimed.emit(ability_id)


# --- Checkpoints ---
func set_checkpoint(
	scene_path: String,
	checkpoint_id_value: String,
	room_name: String = ""
) -> void:
	checkpoint_scene_path = scene_path
	checkpoint_id = checkpoint_id_value
	checkpoint_room_name = room_name


func has_checkpoint() -> bool:
	return checkpoint_scene_path != "" and checkpoint_id != ""


func clear_checkpoint() -> void:
	checkpoint_scene_path = ""
	checkpoint_id = ""
	checkpoint_room_name = ""
	checkpoint_activated = false


func respawn_player() -> void:
	if _transition_lock:
		return

	_transition_lock = true

	if not has_checkpoint():
		print("NO CHECKPOINT - RELOADING CURRENT ROOM")
		_fade_out_and_reload_current_scene()
		return

	print("RESPAWNING")
	print("Scene: ", checkpoint_scene_path)
	print("Checkpoint: ", checkpoint_id)

	pending_spawn_gate_id = ""
	_fade_out_and_load(checkpoint_scene_path)


func rest_at_checkpoint() -> void:
	if _transition_lock:
		return

	_transition_lock = true

	if not has_checkpoint():
		_transition_lock = false
		return

	print("RESTING AT CHECKPOINT: ", checkpoint_id)

	# Fade out
	var tween := create_tween()

	tween.tween_property(
		_fade_rect,
		"color:a",
		0.75,
		0.25
	)

	await tween.finished

	# Reload the checkpoint room.
	get_tree().change_scene_to_file(checkpoint_scene_path)

	# Wait for the new scene and Player to initialize.
	await get_tree().process_frame
	await get_tree().process_frame

	# Put the new player at the checkpoint.
	pending_spawn_gate_id = ""
	_position_player_at_checkpoint()

	# Restore HP/MP on the NEW player.
	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		var player = players[0]

		if player.has_method("restore_full_health"):
			player.restore_full_health()

		if player.has_method("restore_full_mp"):
			player.restore_full_mp()

		if player.has_method("unlock_input"):
			player.unlock_input()

	# Fade back in.
	var fade_in := create_tween()

	fade_in.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		0.35
	)

	await fade_in.finished

	_transition_lock = false


func activate_checkpoint(
	scene_path: String,
	checkpoint_id_value: String
) -> void:
	var key := scene_path + "/" + checkpoint_id_value
	activated_checkpoints[key] = true


func is_checkpoint_activated(
	scene_path: String,
	checkpoint_id_value: String
) -> bool:
	var key := scene_path + "/" + checkpoint_id_value
	return activated_checkpoints.has(key)
