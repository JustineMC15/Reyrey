extends Area2D
class_name TransitionGate

@export var gate_id: String = ""
@export var target_scene_path: String = ""
@export var target_gate_id: String = ""

func _ready() -> void:
	add_to_group("gates")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not GameState.can_trigger_gate():
		return
	if body.is_in_group("player"):
		GameState.go_to_room(target_scene_path, target_gate_id)
