extends Node

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
