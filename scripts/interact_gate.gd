extends Area2D
class_name InteractGate

@export var gate_id: String = ""            # lets another gate land the player exactly here
@export var target_scene_path: String = ""  # scene to load on E press
@export var target_gate_id: String = ""     # which gate_id to spawn at over there
@export var prompt_panel: Panel             # drag this instance's own prompt panel in

var player_inside := false

func _ready() -> void:
	add_to_group("gates")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	_hide_prompt()

func _show_prompt() -> void:
	if not prompt_panel:
		return
	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)

func _hide_prompt() -> void:
	if not prompt_panel:
		return
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)

func _process(_delta: float) -> void:
	if player_inside and GameState.can_trigger_gate() and Input.is_action_just_pressed("interact"):
		_hide_prompt()
		player_inside = false
		GameState.go_to_room(target_scene_path, target_gate_id)
