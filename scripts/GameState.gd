extends Node
var abilities: Dictionary = {
	"double_jump": false,
	"dash": false,
}
# --- Room / Gate transition state ---
var pending_spawn_gate_id: String = ""
var _transition_lock: bool = false

# --- Enemy death persistence (for later, when enemies exist) ---
# Key format: "RoomName/EnemyStableID" -> true
var dead_enemies: Dictionary = {}

# --- Fade overlay, built in code so you don't need a separate scene ---
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
const FADE_DURATION := 0.25

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

# --- Enemy death helpers (wire these up when Guiding Star exists) ---
func mark_enemy_dead(room_name: String, enemy_id: String) -> void:
	dead_enemies[room_name + "/" + enemy_id] = true

func is_enemy_dead(room_name: String, enemy_id: String) -> bool:
	return dead_enemies.has(room_name + "/" + enemy_id)

func clear_room_enemy_deaths(room_name: String) -> void:
	for key in dead_enemies.keys():
		if key.begins_with(room_name + "/"):
			dead_enemies.erase(key)

# --- Room transition ---
func can_trigger_gate() -> bool:
	return not _transition_lock

func go_to_room(target_scene_path: String, target_gate_id: String) -> void:
	if _transition_lock:
		return
	_transition_lock = true
	pending_spawn_gate_id = target_gate_id
	_fade_out_and_load(target_scene_path)

func _fade_out_and_load(target_scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene_path)
		call_deferred("_on_new_room_ready")
	)

func _on_new_room_ready() -> void:
	_position_player_at_gate()
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

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	_transition_lock = false
	
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

func claim_ability(ability_id: String, player: Node, icon: Texture2D = null) -> void:
	if has_ability(ability_id):
		return
	_transition_lock = true
	if player and player.has_method("lock_input"):
		player.lock_input()
	_run_claim_sequence(ability_id, player, icon)

func _run_claim_sequence(ability_id: String, player: Node, icon: Texture2D) -> void:
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
		pulse.tween_property(icon_rect, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(icon_rect, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

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

	# charge pulse on the player sprite while the ceremony plays
	var player_glow: Tween
	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		player_glow = create_tween().set_loops()
		player_glow.tween_property(sprite, "modulate", Color(2, 2, 1.4, 1), 0.4)
		player_glow.tween_property(sprite, "modulate", Color.WHITE, 0.4)

	var fade_in := create_tween()
	fade_in.tween_property(dim, "color:a", 0.85, 0.4)
	fade_in.parallel().tween_property(vbox, "modulate:a", 1.0, 0.6)
	await fade_in.finished

	await get_tree().create_timer(0.2).timeout  # debounce, avoid same-frame input
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame

	if player_glow:
		player_glow.kill()
		if player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").modulate = Color.WHITE

	var fade_out := create_tween()
	fade_out.tween_property(dim, "color:a", 0.0, 0.3)
	fade_out.parallel().tween_property(vbox, "modulate:a", 0.0, 0.3)
	await fade_out.finished

	layer.queue_free()
	unlock_ability(ability_id)
	if player and player.has_method("unlock_input"):
		player.unlock_input()
	_transition_lock = false
	ability_claimed.emit(ability_id)
