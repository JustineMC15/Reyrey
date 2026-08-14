extends Area2D
class_name TransitionGate

@export var gate_id: String = ""
@export var target_scene_path: String = ""
@export var target_gate_id: String = ""


func _ready() -> void:
	add_to_group("gates")
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not GameState.can_trigger_gate():
		return

	if area.is_in_group("player_detection"):
		GameState.go_to_room(target_scene_path, target_gate_id)
