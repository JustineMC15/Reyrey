extends Area2D
class_name InteractGate

@export var gate_id: String = ""            # lets another gate land the player exactly here
@export var target_scene_path: String = ""  # scene to load on E press
@export var target_gate_id: String = ""     # which gate_id to spawn at over there
@export var prompt_panel: Panel             # drag this instance's own prompt panel in

@export_category("Entry")
@export var entry_type: TransitionGate.EntryType = TransitionGate.EntryType.WALK
@export var entry_direction: Vector2 = Vector2.RIGHT
@export var entry_distance: float = 180.0
@export var jump_velocity: Vector2 = Vector2(400.0, -800.0)

var player_inside := false
var triggered := false


func _ready() -> void:
	add_to_group("gates")

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	if triggered:
		return

	player_inside = true
	_show_prompt()


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player_inside = false
	_hide_prompt()


func _show_prompt() -> void:
	if not prompt_panel:
		return

	prompt_panel.show()

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		1.0,
		0.25
	)


func _hide_prompt() -> void:
	if not prompt_panel:
		return

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		0.0,
		0.25
	)

	tween.tween_callback(prompt_panel.hide)


func _process(_delta: float) -> void:
	if triggered:
		return

	if not player_inside:
		return

	if not GameState.can_trigger_gate():
		return

	if not Input.is_action_just_pressed("interact"):
		return

	triggered = true
	player_inside = false

	_hide_prompt()

	monitoring = false

	GameState.go_to_room(
		target_scene_path,
		target_gate_id,
		entry_type,
		entry_direction,
		entry_distance,
		jump_velocity
	)
